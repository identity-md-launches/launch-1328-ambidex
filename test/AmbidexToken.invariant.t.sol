// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {AmbidexToken} from "../src/AmbidexToken.sol";

/// @title Handler that drives AmbidexToken with random call sequences.
/// @notice Two layers, as the fizz handler guide lays out. The *raw* layer calls the token with
/// unrestricted amounts and arbitrary addresses so the campaign reaches every revert path. The
/// *clamped* layer derives inputs from current state so the campaign also reaches the success
/// paths deep into a sequence. Every token call is wrapped in try/catch and checked against an
/// independent model of what ERC-20 promises: the exact outcome (success or which ERC-6093 error)
/// is predicted *before* the call and compared afterwards, so a wrong revert, a silent failure or
/// a `false` return is caught at the call that produced it, not only by the global invariants.
/// @dev Ghost state:
///  - `ledger`: the model balance of every address the campaign has touched;
///  - `modelAllowance`: the model allowance per (owner, spender);
///  - `approvedCumulative` / `pulled`: how much an owner ever granted a spender, saturating, and how
///    much that spender actually moved out of the owner through `transferFrom`.
contract AmbidexHandler is Test {
    AmbidexToken public immutable token;
    uint256 public immutable supply;

    /// @dev Named actors: the deployer (initial holder), five users and the token contract itself as
    /// a sink nobody controls. Seeds that fall past the end of the list become a fresh stranger.
    address[] public actors;

    address[] public touched;
    mapping(address => bool) public seen;

    struct Pair {
        address owner;
        address spender;
    }

    Pair[] public pairs;
    mapping(address => mapping(address => bool)) public pairSeen;

    mapping(address => uint256) public ledger;
    mapping(address => mapping(address => uint256)) public modelAllowance;
    mapping(address => mapping(address => uint256)) public approvedCumulative;
    mapping(address => mapping(address => uint256)) public pulled;

    // Coverage counters, so a run can be checked for not being vacuous.
    uint256 public calls;
    uint256 public transfersOk;
    uint256 public transfersRevertedBalance;
    uint256 public transfersRevertedZeroReceiver;
    uint256 public transferFromOk;
    uint256 public transferFromRevertedAllowance;
    uint256 public transferFromRevertedBalance;
    uint256 public transferFromRevertedZeroReceiver;
    uint256 public approvesOk;
    uint256 public approvesRevertedZeroSpender;
    uint256 public junkCallsRejected;
    uint256 public valueCallsRejected;

    constructor(AmbidexToken token_, address deployer, address[] memory users) {
        token = token_;
        supply = token_.totalSupply();
        actors.push(deployer);
        for (uint256 i = 0; i < users.length; i++) {
            actors.push(users[i]);
        }
        actors.push(address(token_));
        for (uint256 i = 0; i < actors.length; i++) {
            _touch(actors[i]);
        }
        // The deployer holds everything at the start; nothing else was ever minted.
        ledger[deployer] = supply;
    }

    // ---------------------------------------------------------------------------------------------
    // Raw layer: unrestricted inputs, exact outcome prediction
    // ---------------------------------------------------------------------------------------------

    /// @notice `transfer` from an actor (or a stranger) to any address with any amount.
    function transferRaw(uint256 fromSeed, address to, uint256 amount) public {
        calls++;
        address from = _caller(fromSeed);
        _touch(from);
        _touch(to);

        bytes memory expectedError;
        if (to == address(0)) {
            expectedError = abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0));
        } else if (ledger[from] < amount) {
            expectedError =
                abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, from, ledger[from], amount);
        }

        vm.prank(from);
        try token.transfer(to, amount) returns (bool ok) {
            assertEq(expectedError.length, 0, "transfer succeeded where the model expected a revert");
            assertTrue(ok, "transfer returned false");
            ledger[from] -= amount;
            ledger[to] += amount;
            transfersOk++;
        } catch (bytes memory err) {
            assertGt(expectedError.length, 0, "transfer reverted where the model expected success");
            assertEq(err, expectedError, "transfer reverted with a different error than the model");
            if (to == address(0)) transfersRevertedZeroReceiver++;
            else transfersRevertedBalance++;
        }
    }

    /// @notice `transferFrom` by an actor (or a stranger) out of an actor to any address, any amount.
    function transferFromRaw(uint256 spenderSeed, uint256 ownerSeed, address to, uint256 amount) public {
        calls++;
        address spender = _caller(spenderSeed);
        address owner = _actor(ownerSeed);
        _touch(spender);
        _touch(owner);
        _touch(to);
        _touchPair(owner, spender);

        uint256 allowed = modelAllowance[owner][spender];
        bytes memory expectedError;
        // OpenZeppelin spends the allowance before it checks the receiver or the balance.
        if (allowed != type(uint256).max && allowed < amount) {
            expectedError =
                abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, allowed, amount);
        } else if (to == address(0)) {
            expectedError = abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0));
        } else if (ledger[owner] < amount) {
            expectedError =
                abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, owner, ledger[owner], amount);
        }

        vm.prank(spender);
        try token.transferFrom(owner, to, amount) returns (bool ok) {
            assertEq(expectedError.length, 0, "transferFrom succeeded where the model expected a revert");
            assertTrue(ok, "transferFrom returned false");
            if (allowed != type(uint256).max) modelAllowance[owner][spender] = allowed - amount;
            ledger[owner] -= amount;
            ledger[to] += amount;
            pulled[owner][spender] += amount;
            transferFromOk++;
        } catch (bytes memory err) {
            assertGt(expectedError.length, 0, "transferFrom reverted where the model expected success");
            assertEq(err, expectedError, "transferFrom reverted with a different error than the model");
            if (allowed != type(uint256).max && allowed < amount) transferFromRevertedAllowance++;
            else if (to == address(0)) transferFromRevertedZeroReceiver++;
            else transferFromRevertedBalance++;
        }
    }

    /// @notice `approve` by an actor (or a stranger) for any spender and any amount.
    function approveRaw(uint256 ownerSeed, address spender, uint256 amount) public {
        calls++;
        address owner = _caller(ownerSeed);
        _touch(owner);
        _touch(spender);
        _touchPair(owner, spender);

        vm.prank(owner);
        try token.approve(spender, amount) returns (bool ok) {
            assertTrue(spender != address(0), "approve accepted the zero spender");
            assertTrue(ok, "approve returned false");
            modelAllowance[owner][spender] = amount;
            uint256 cumulative = approvedCumulative[owner][spender];
            unchecked {
                uint256 next = cumulative + amount;
                approvedCumulative[owner][spender] = next < cumulative ? type(uint256).max : next;
            }
            approvesOk++;
        } catch (bytes memory err) {
            assertEq(spender, address(0), "approve reverted for a non-zero spender");
            assertEq(
                err,
                abi.encodeWithSelector(IERC20Errors.ERC20InvalidSpender.selector, address(0)),
                "approve reverted with a different error than the model"
            );
            approvesRevertedZeroSpender++;
        }
    }

    /// @notice Any selector the token does not define, from anyone, with any arguments: it must be
    /// rejected. This is the "no hidden privileged function" property over random sequences.
    function junkCall(uint256 callerSeed, bytes4 selector, bytes calldata args) public {
        calls++;
        address caller = _caller(callerSeed);
        while (_isDefined(selector)) {
            selector = bytes4(keccak256(abi.encodePacked(selector)));
        }
        vm.prank(caller);
        (bool ok,) = address(token).call(abi.encodePacked(selector, args));
        assertFalse(ok, "the token accepted an undefined selector");
        junkCallsRejected++;
    }

    /// @notice Ether sent with any call, defined or not, must be refused: nothing is payable.
    function valueCall(uint256 callerSeed, uint8 which, uint256 value) public {
        calls++;
        address caller = _caller(callerSeed);
        // The token itself is an actor as a sink. Funding it with vm.deal would put ether on it
        // outside any call, which is not what this handler tests, so it never acts as the caller.
        if (caller == address(token)) caller = actors[0];
        value = bound(value, 1, 1000 ether);
        bytes memory data;
        uint8 pick = which % 5;
        if (pick == 0) data = abi.encodeCall(IERC20.transfer, (caller, 0));
        else if (pick == 1) data = abi.encodeCall(IERC20.approve, (caller, 1));
        else if (pick == 2) data = abi.encodeCall(IERC20.transferFrom, (caller, caller, 0));
        else if (pick == 3) data = abi.encodeCall(IERC20.balanceOf, (caller));
        // pick == 4: empty calldata, the receive/fallback path.

        vm.deal(caller, value);
        vm.prank(caller);
        (bool ok,) = address(token).call{value: value}(data);
        assertFalse(ok, "the token accepted ether");
        assertEq(address(token).balance, 0, "the token holds ether");
        valueCallsRejected++;
    }

    // ---------------------------------------------------------------------------------------------
    // Clamped layer: inputs derived from state so the success paths are reached
    // ---------------------------------------------------------------------------------------------

    function transferBounded(uint256 fromSeed, uint256 toSeed, uint256 amount) public {
        address from = _actor(fromSeed);
        amount = bound(amount, 0, ledger[from]);
        transferRaw(fromSeed % actors.length, _actor(toSeed), amount);
    }

    function transferFull(uint256 fromSeed, uint256 toSeed) public {
        address from = _actor(fromSeed);
        transferRaw(fromSeed % actors.length, _actor(toSeed), ledger[from]);
    }

    function transferOneWei(uint256 fromSeed, uint256 toSeed) public {
        transferRaw(fromSeed % actors.length, _actor(toSeed), 1);
    }

    function approveBounded(uint256 ownerSeed, uint256 spenderSeed, uint256 amount) public {
        amount = bound(amount, 0, supply);
        approveRaw(ownerSeed % actors.length, _actor(spenderSeed), amount);
    }

    function approveMax(uint256 ownerSeed, uint256 spenderSeed) public {
        approveRaw(ownerSeed % actors.length, _actor(spenderSeed), type(uint256).max);
    }

    function transferFromBounded(uint256 spenderSeed, uint256 ownerSeed, uint256 toSeed, uint256 amount) public {
        address spender = _actor(spenderSeed);
        address owner = _actor(ownerSeed);
        uint256 cap = ledger[owner];
        uint256 allowed = modelAllowance[owner][spender];
        if (allowed < cap) cap = allowed;
        amount = bound(amount, 0, cap);
        transferFromRaw(spenderSeed % actors.length, ownerSeed, _actor(toSeed), amount);
    }

    function transferFromFull(uint256 spenderSeed, uint256 ownerSeed, uint256 toSeed) public {
        address spender = _actor(spenderSeed);
        address owner = _actor(ownerSeed);
        uint256 cap = ledger[owner];
        uint256 allowed = modelAllowance[owner][spender];
        if (allowed < cap) cap = allowed;
        transferFromRaw(spenderSeed % actors.length, ownerSeed, _actor(toSeed), cap);
    }

    // ---------------------------------------------------------------------------------------------
    // Views for the invariants
    // ---------------------------------------------------------------------------------------------

    function touchedCount() external view returns (uint256) {
        return touched.length;
    }

    function pairCount() external view returns (uint256) {
        return pairs.length;
    }

    function actorCount() external view returns (uint256) {
        return actors.length;
    }

    function sumOfTouchedBalances() external view returns (uint256 sum) {
        for (uint256 i = 0; i < touched.length; i++) {
            sum += token.balanceOf(touched[i]);
        }
    }

    // ---------------------------------------------------------------------------------------------
    // Internals
    // ---------------------------------------------------------------------------------------------

    function _actor(uint256 seed) internal view returns (address) {
        return actors[seed % actors.length];
    }

    /// @dev One slot past the actors is a stranger derived from the seed: an address that holds
    /// nothing and was never approved, so its calls exercise the unauthorised paths.
    function _caller(uint256 seed) internal view returns (address) {
        uint256 slot = seed % (actors.length + 1);
        if (slot < actors.length) return actors[slot];
        address stranger = address(uint160(uint256(keccak256(abi.encodePacked("stranger", seed)))));
        return stranger == address(0) ? actors[0] : stranger;
    }

    function _touch(address a) internal {
        if (!seen[a]) {
            seen[a] = true;
            touched.push(a);
        }
    }

    function _touchPair(address owner, address spender) internal {
        if (!pairSeen[owner][spender]) {
            pairSeen[owner][spender] = true;
            pairs.push(Pair(owner, spender));
        }
    }

    function _isDefined(bytes4 selector) internal view returns (bool) {
        return selector == IERC20.transfer.selector || selector == IERC20.transferFrom.selector
            || selector == IERC20.approve.selector || selector == IERC20.allowance.selector
            || selector == IERC20.balanceOf.selector || selector == IERC20.totalSupply.selector
            || selector == token.name.selector || selector == token.symbol.selector
            || selector == token.decimals.selector || selector == token.NAME.selector
            || selector == token.SYMBOL.selector || selector == token.DECIMALS.selector
            || selector == token.TOTAL_SUPPLY.selector;
    }
}

/// @title Invariants of AMBIDEX over random call sequences.
/// @dev Fixed supply, conservation of balances, a model ledger the real balances must match, an
/// allowance ledger the real allowances must match, "nobody pulls more than was approved", nothing
/// payable, nothing privileged, and metadata and code that never change. Each invariant is checked
/// after every handler call. Run counts are set inline because foundry.toml is not ours to change.
/// forge-config: default.invariant.runs = 256
/// forge-config: default.invariant.depth = 64
/// forge-config: default.invariant.fail-on-revert = true
contract AmbidexTokenInvariantTest is Test {
    uint256 internal constant EXPECTED_SUPPLY = 1_000_000_000 ether;

    address internal deployer = makeAddr("deployer");
    AmbidexToken internal token;
    AmbidexHandler internal handler;
    bytes32 internal codeHashAtDeployment;

    function setUp() public {
        vm.prank(deployer);
        token = new AmbidexToken();
        codeHashAtDeployment = address(token).codehash;

        address[] memory users = new address[](5);
        users[0] = makeAddr("alice");
        users[1] = makeAddr("bob");
        users[2] = makeAddr("carol");
        users[3] = makeAddr("dave");
        users[4] = makeAddr("eve");
        handler = new AmbidexHandler(token, deployer, users);

        targetContract(address(handler));
        bytes4[] memory selectors = new bytes4[](12);
        selectors[0] = handler.transferRaw.selector;
        selectors[1] = handler.transferFromRaw.selector;
        selectors[2] = handler.approveRaw.selector;
        selectors[3] = handler.junkCall.selector;
        selectors[4] = handler.valueCall.selector;
        selectors[5] = handler.transferBounded.selector;
        selectors[6] = handler.transferFull.selector;
        selectors[7] = handler.transferOneWei.selector;
        selectors[8] = handler.approveBounded.selector;
        selectors[9] = handler.approveMax.selector;
        selectors[10] = handler.transferFromBounded.selector;
        selectors[11] = handler.transferFromFull.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    /// @notice The supply is fixed: no call sequence mints or burns.
    function invariant_totalSupplyNeverChanges() public view {
        assertEq(token.totalSupply(), EXPECTED_SUPPLY, "the supply changed");
        assertEq(token.totalSupply(), token.TOTAL_SUPPLY(), "totalSupply disagrees with the constant");
    }

    /// @notice Conservation: everything the token owes, summed over every address the campaign ever
    /// touched, is exactly the supply. Tokens are neither created nor lost on any path.
    function invariant_balancesSumToSupply() public view {
        assertEq(handler.sumOfTouchedBalances(), EXPECTED_SUPPLY, "balances do not sum to the supply");
    }

    /// @notice Every touched balance equals the model ledger, and none exceeds the supply.
    function invariant_balancesMatchTheModelLedger() public view {
        uint256 n = handler.touchedCount();
        for (uint256 i = 0; i < n; i++) {
            address a = handler.touched(i);
            uint256 real = token.balanceOf(a);
            assertEq(real, handler.ledger(a), "a balance drifted from the model");
            assertLe(real, EXPECTED_SUPPLY, "a balance exceeds the supply");
        }
    }

    /// @notice The zero address never holds anything: there is no burn path and no transfer to it.
    function invariant_zeroAddressHoldsNothing() public view {
        assertEq(token.balanceOf(address(0)), 0, "the zero address holds tokens");
    }

    /// @notice Every allowance the campaign touched equals the model.
    function invariant_allowancesMatchTheModel() public view {
        uint256 n = handler.pairCount();
        for (uint256 i = 0; i < n; i++) {
            (address owner, address spender) = handler.pairs(i);
            assertEq(token.allowance(owner, spender), handler.modelAllowance(owner, spender), "an allowance drifted");
        }
    }

    /// @notice Access control: a spender never moves more out of an owner than the owner ever
    /// granted, and a spender who was never approved moves nothing.
    function invariant_nobodyPullsMoreThanApproved() public view {
        uint256 n = handler.pairCount();
        for (uint256 i = 0; i < n; i++) {
            (address owner, address spender) = handler.pairs(i);
            assertLe(
                handler.pulled(owner, spender),
                handler.approvedCumulative(owner, spender),
                "a spender moved more than it was ever approved for"
            );
        }
    }

    /// @notice The token never ends up holding ether, whatever was sent with whatever call.
    function invariant_tokenHoldsNoEther() public view {
        assertEq(address(token).balance, 0, "the token holds ether");
    }

    /// @notice Nothing in any sequence changes what the token reports about itself, and its code
    /// stays what was deployed (no self-destruct, no metamorphic redeploy).
    function invariant_metadataAndCodeAreImmutable() public view {
        assertEq(token.name(), "AMBIDEX");
        assertEq(token.symbol(), "AMBI");
        assertEq(token.decimals(), 18);
        assertEq(token.TOTAL_SUPPLY(), EXPECTED_SUPPLY);
        assertEq(address(token).codehash, codeHashAtDeployment, "the runtime code changed");
    }

    /// @notice Guards against a vacuous campaign: the last run must have driven the token for real.
    /// Runs restart from a snapshot, so the counters describe the final sequence only; the
    /// assertions are the ones that cannot fail over a sequence of this depth.
    function afterInvariant() public view {
        assertGt(handler.calls(), 0, "the handler was never called");
        assertGt(
            handler.transfersOk() + handler.transferFromOk() + handler.approvesOk(),
            0,
            "no handler call ever changed state"
        );
    }
}

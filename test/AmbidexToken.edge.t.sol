// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {AmbidexToken} from "../src/AmbidexToken.sol";

/// @title Edge cases and fuzzed failure paths for AMBIDEX.
/// @dev Complements test/AmbidexToken.t.sol (happy paths and fixed failure cases) and
/// test/AmbidexToken.invariant.t.sol (random sequences). Here each property is one call at the
/// boundary: zero, one wei, the whole supply, the maximum, the same call twice, a caller the code
/// did not assume, and the exact ERC-6093 error with exact arguments on every revert.
/// forge-config: default.fuzz.runs = 1000
contract AmbidexTokenEdgeTest is Test {
    uint256 internal constant EXPECTED_SUPPLY = 1_000_000_000 ether;
    uint256 internal constant MAX = type(uint256).max;

    address internal deployer = makeAddr("deployer");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal spender = makeAddr("spender");
    address internal stranger = makeAddr("stranger");

    AmbidexToken internal token;

    function setUp() public {
        vm.prank(deployer);
        token = new AmbidexToken();
    }

    // ---------------------------------------------------------------------------------------------
    // Supply pinned against the brief, in terms of the decimals the token reports
    // ---------------------------------------------------------------------------------------------

    function test_supplyIsExactlyOneBillionWholeTokensAtReportedDecimals() public view {
        uint256 unit = 10 ** uint256(token.decimals());
        assertEq(token.totalSupply() / unit, 1_000_000_000, "not one billion whole tokens");
        assertEq(token.totalSupply() % unit, 0, "supply has a fractional remainder");
        assertEq(token.totalSupply(), 10 ** 27);
        assertLe(token.totalSupply(), type(uint128).max, "supply does not fit the narrow types pools use");
    }

    function test_onlyOneHolderAfterDeployment() public view {
        assertEq(token.balanceOf(deployer), token.totalSupply());
        assertEq(token.balanceOf(address(0)), 0);
        assertEq(token.balanceOf(address(token)), 0);
        assertEq(token.balanceOf(address(this)), 0);
    }

    function testFuzz_whoeverCreatesTheTokenHoldsTheSupply(uint256 seed) public {
        address creator = address(uint160(uint256(keccak256(abi.encode("creator", seed)))));
        vm.assume(creator != address(0));
        vm.prank(creator);
        AmbidexToken fresh = new AmbidexToken();
        assertEq(fresh.balanceOf(creator), EXPECTED_SUPPLY, "the creator does not hold the supply");
        assertEq(fresh.totalSupply(), EXPECTED_SUPPLY);
        // Separate deployments are separate ledgers: the first token is untouched.
        assertEq(token.balanceOf(creator), 0);
    }

    // ---------------------------------------------------------------------------------------------
    // transfer at the boundaries
    // ---------------------------------------------------------------------------------------------

    function test_transferOneWei() public {
        vm.prank(deployer);
        assertTrue(token.transfer(alice, 1));
        assertEq(token.balanceOf(alice), 1);
        assertEq(token.balanceOf(deployer), EXPECTED_SUPPLY - 1);
    }

    function test_transferOneWeiMoreThanBalanceReverts() public {
        vm.prank(deployer);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector, deployer, EXPECTED_SUPPLY, EXPECTED_SUPPLY + 1
            )
        );
        token.transfer(alice, EXPECTED_SUPPLY + 1);
        assertEq(token.balanceOf(deployer), EXPECTED_SUPPLY);
    }

    function test_transferMaxUintRevertsWithoutOverflow() public {
        vm.prank(deployer);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, deployer, EXPECTED_SUPPLY, MAX)
        );
        token.transfer(alice, MAX);
    }

    function test_selfTransferOfMoreThanHeldReverts() public {
        vm.prank(deployer);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector, deployer, EXPECTED_SUPPLY, EXPECTED_SUPPLY + 1
            )
        );
        token.transfer(deployer, EXPECTED_SUPPLY + 1);
    }

    function test_transferFromTheZeroAddressIsImpossible() public {
        // Even a caller that somehow is the zero address cannot move or create tokens.
        vm.prank(address(0));
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSender.selector, address(0)));
        token.transfer(alice, 0);
    }

    function test_zeroAmountTransferToZeroAddressStillReverts() public {
        vm.prank(deployer);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        token.transfer(address(0), 0);
    }

    function test_sameTransferTwiceMovesTwice() public {
        vm.startPrank(deployer);
        token.transfer(alice, 5 ether);
        token.transfer(alice, 5 ether);
        vm.stopPrank();
        assertEq(token.balanceOf(alice), 10 ether);
        assertEq(token.balanceOf(deployer), EXPECTED_SUPPLY - 10 ether);
    }

    function test_transferAfterEmptyingRevertsEvenForOneWei() public {
        vm.prank(deployer);
        token.transfer(alice, EXPECTED_SUPPLY);
        vm.prank(deployer);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, deployer, 0, 1));
        token.transfer(alice, 1);
        // Zero is still fine from an empty account.
        vm.prank(deployer);
        assertTrue(token.transfer(alice, 0));
    }

    /// @dev Tokens sent to the token's own address are stuck: there is no recovery function, by
    /// design (no admin). Pinned so a later change that adds one is a visible change of policy.
    function test_tokensSentToTheContractItselfAreStrandedByDesign() public {
        vm.prank(deployer);
        assertTrue(token.transfer(address(token), 1 ether));
        assertEq(token.balanceOf(address(token)), 1 ether);
        assertEq(token.totalSupply(), EXPECTED_SUPPLY);

        string[4] memory signatures =
            ["recoverERC20(address,uint256)", "rescue(address)", "sweep(address)", "withdrawToken(address,uint256)"];
        for (uint256 i = 0; i < signatures.length; i++) {
            vm.prank(deployer);
            (bool ok,) = address(token).call(abi.encodeWithSignature(signatures[i], address(token), 1 ether));
            assertFalse(ok, string.concat("unexpected recovery function: ", signatures[i]));
        }
        assertEq(token.balanceOf(address(token)), 1 ether);
    }

    function testFuzz_transferRevertsExactlyWhenAmountExceedsBalance(uint256 held, uint256 amount) public {
        held = bound(held, 0, EXPECTED_SUPPLY - 1);
        amount = bound(amount, held + 1, MAX);
        vm.prank(deployer);
        token.transfer(alice, held);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, held, amount));
        token.transfer(bob, amount);

        assertEq(token.balanceOf(alice), held, "a failed transfer changed the sender");
        assertEq(token.balanceOf(bob), 0, "a failed transfer changed the receiver");
    }

    function testFuzz_transferSucceedsForAnyAmountUpToBalance(uint256 held, uint256 amount) public {
        held = bound(held, 0, EXPECTED_SUPPLY);
        amount = bound(amount, 0, held);
        vm.prank(deployer);
        token.transfer(alice, held);

        vm.prank(alice);
        vm.expectEmit(true, true, true, true, address(token));
        emit IERC20.Transfer(alice, bob, amount);
        assertTrue(token.transfer(bob, amount));

        assertEq(token.balanceOf(alice), held - amount);
        assertEq(token.balanceOf(bob), amount);
    }

    /// @dev Any non-zero address can receive, including precompiles, the token itself and the
    /// sender, and whoever received can send it on: no hook, no block list, no code check.
    function testFuzz_anyNonZeroAddressCanReceiveAndForward(uint160 toRaw, uint256 amount) public {
        address to = address(uint160(bound(uint256(toRaw), 1, type(uint160).max)));
        vm.assume(to != deployer && to != VM_ADDRESS && to != CONSOLE);
        amount = bound(amount, 1, EXPECTED_SUPPLY);

        vm.prank(deployer);
        assertTrue(token.transfer(to, amount));
        assertEq(token.balanceOf(to), amount);

        vm.prank(to);
        assertTrue(token.transfer(bob, amount));
        assertEq(token.balanceOf(to), 0);
        assertEq(token.balanceOf(bob), amount);
    }

    function testFuzz_roundTripRestoresEveryBalance(uint256 amount) public {
        amount = bound(amount, 0, EXPECTED_SUPPLY);
        vm.prank(deployer);
        token.transfer(alice, amount);
        vm.prank(alice);
        token.transfer(deployer, amount);
        assertEq(token.balanceOf(deployer), EXPECTED_SUPPLY);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.totalSupply(), EXPECTED_SUPPLY);
    }

    function testFuzz_twoTransfersEqualTheirSum(uint256 a, uint256 b) public {
        a = bound(a, 0, EXPECTED_SUPPLY);
        b = bound(b, 0, EXPECTED_SUPPLY - a);
        vm.startPrank(deployer);
        token.transfer(alice, a);
        token.transfer(alice, b);
        vm.stopPrank();
        assertEq(token.balanceOf(alice), a + b);
        assertEq(token.balanceOf(deployer), EXPECTED_SUPPLY - a - b);
        assertEq(token.balanceOf(alice) + token.balanceOf(deployer), EXPECTED_SUPPLY);
    }

    // ---------------------------------------------------------------------------------------------
    // approve at the boundaries
    // ---------------------------------------------------------------------------------------------

    function test_approveOverwritesInsteadOfAccumulating() public {
        vm.startPrank(deployer);
        token.approve(spender, 100 ether);
        token.approve(spender, 50 ether);
        vm.stopPrank();
        assertEq(token.allowance(deployer, spender), 50 ether, "approve accumulated");
    }

    function test_approveZeroClearsAllowance() public {
        vm.startPrank(deployer);
        token.approve(spender, 100 ether);
        token.approve(spender, 0);
        vm.stopPrank();
        assertEq(token.allowance(deployer, spender), 0);
        vm.prank(spender);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, 0, 1));
        token.transferFrom(deployer, bob, 1);
    }

    function test_anyoneMayApproveMoreThanTheyHold() public {
        // An allowance is a promise, not a balance: approving beyond the balance is allowed, and
        // the pull fails on balance, not on allowance.
        vm.prank(stranger);
        assertTrue(token.approve(spender, MAX));
        assertEq(token.allowance(stranger, spender), MAX);
        vm.prank(spender);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, stranger, 0, 1));
        token.transferFrom(stranger, bob, 1);
    }

    function testFuzz_approveSetsExactlyAndEmits(uint256 first, uint256 second) public {
        vm.startPrank(deployer);
        vm.expectEmit(true, true, true, true, address(token));
        emit IERC20.Approval(deployer, spender, first);
        assertTrue(token.approve(spender, first));
        assertEq(token.allowance(deployer, spender), first);

        vm.expectEmit(true, true, true, true, address(token));
        emit IERC20.Approval(deployer, spender, second);
        assertTrue(token.approve(spender, second));
        vm.stopPrank();
        assertEq(token.allowance(deployer, spender), second, "second approve did not overwrite");
        // Approvals never move tokens.
        assertEq(token.balanceOf(deployer), EXPECTED_SUPPLY);
        assertEq(token.balanceOf(spender), 0);
    }

    function testFuzz_allowancesAreDirectional(uint256 amount) public {
        vm.prank(deployer);
        token.approve(spender, amount);
        assertEq(token.allowance(spender, deployer), 0, "approval leaked in the other direction");
        assertEq(token.allowance(deployer, alice), 0, "approval leaked to another spender");
    }

    // ---------------------------------------------------------------------------------------------
    // transferFrom at the boundaries
    // ---------------------------------------------------------------------------------------------

    function test_transferFromOneWeiDecrementsAllowanceByOne() public {
        vm.prank(deployer);
        token.approve(spender, 2);
        vm.prank(spender);
        assertTrue(token.transferFrom(deployer, alice, 1));
        assertEq(token.allowance(deployer, spender), 1);
        assertEq(token.balanceOf(alice), 1);
    }

    function test_transferFromExactAllowanceLeavesZero() public {
        vm.prank(deployer);
        token.approve(spender, 7 ether);
        vm.prank(spender);
        assertTrue(token.transferFrom(deployer, alice, 7 ether));
        assertEq(token.allowance(deployer, spender), 0);
        vm.prank(spender);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, 0, 1));
        token.transferFrom(deployer, alice, 1);
    }

    function test_transferFromWholeSupplyWithInfiniteAllowance() public {
        vm.prank(deployer);
        token.approve(spender, MAX);
        vm.prank(spender);
        assertTrue(token.transferFrom(deployer, alice, EXPECTED_SUPPLY));
        assertEq(token.balanceOf(alice), EXPECTED_SUPPLY);
        assertEq(token.balanceOf(deployer), 0);
        assertEq(token.allowance(deployer, spender), MAX, "infinite allowance was decremented");
    }

    /// @dev OpenZeppelin v5 gives the owner no shortcut: pulling your own tokens through
    /// transferFrom needs a self-approval like any other spender.
    function test_ownerCannotTransferFromItselfWithoutSelfApproval() public {
        vm.prank(deployer);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, deployer, 0, 1));
        token.transferFrom(deployer, alice, 1);

        vm.prank(deployer);
        token.approve(deployer, 1);
        vm.prank(deployer);
        assertTrue(token.transferFrom(deployer, alice, 1));
        assertEq(token.allowance(deployer, deployer), 0);
        assertEq(token.balanceOf(alice), 1);
    }

    /// @dev Standard ERC-20 semantics worth pinning: a zero-amount transferFrom needs no allowance.
    /// It moves nothing and changes no state, so it is harmless, but it does emit a Transfer of 0.
    function test_zeroAmountTransferFromNeedsNoAllowance() public {
        vm.prank(stranger);
        vm.expectEmit(true, true, true, true, address(token));
        emit IERC20.Transfer(deployer, stranger, 0);
        assertTrue(token.transferFrom(deployer, stranger, 0));
        assertEq(token.balanceOf(deployer), EXPECTED_SUPPLY);
        assertEq(token.balanceOf(stranger), 0);
        assertEq(token.allowance(deployer, stranger), 0);
    }

    /// @dev Revert precedence: the allowance is checked before the receiver and before the balance.
    function test_transferFromCheckOrderIsAllowanceThenReceiverThenBalance() public {
        // No allowance, zero receiver: allowance error wins.
        vm.prank(spender);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, 0, 1));
        token.transferFrom(deployer, address(0), 1);

        // Allowance present, zero receiver: receiver error.
        vm.prank(deployer);
        token.approve(spender, MAX);
        vm.prank(spender);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        token.transferFrom(deployer, address(0), 1);

        // Allowance present, good receiver, owner short: balance error with the owner's numbers.
        vm.prank(spender);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector, deployer, EXPECTED_SUPPLY, EXPECTED_SUPPLY + 1
            )
        );
        token.transferFrom(deployer, alice, EXPECTED_SUPPLY + 1);
        assertEq(token.allowance(deployer, spender), MAX, "a failed transferFrom spent the allowance");
    }

    function testFuzz_transferFromDecrementsAllowanceExactly(uint256 allowance, uint256 amount) public {
        allowance = bound(allowance, 0, EXPECTED_SUPPLY);
        amount = bound(amount, 0, allowance);
        vm.prank(deployer);
        token.approve(spender, allowance);

        vm.prank(spender);
        vm.expectEmit(true, true, true, true, address(token));
        emit IERC20.Transfer(deployer, alice, amount);
        assertTrue(token.transferFrom(deployer, alice, amount));

        assertEq(token.allowance(deployer, spender), allowance - amount, "allowance not decremented exactly");
        assertEq(token.balanceOf(alice), amount);
        assertEq(token.balanceOf(deployer), EXPECTED_SUPPLY - amount);
        assertEq(token.balanceOf(spender), 0, "the spender received tokens it only relayed");
    }

    function testFuzz_transferFromRevertsExactlyAboveAllowance(uint256 allowance, uint256 amount) public {
        allowance = bound(allowance, 0, EXPECTED_SUPPLY);
        amount = bound(amount, allowance + 1, MAX);
        vm.prank(deployer);
        token.approve(spender, allowance);

        vm.prank(spender);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, allowance, amount)
        );
        token.transferFrom(deployer, alice, amount);

        assertEq(token.allowance(deployer, spender), allowance, "a failed pull changed the allowance");
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(deployer), EXPECTED_SUPPLY);
    }

    function testFuzz_infiniteAllowanceIsNeverDecremented(uint256 amount) public {
        amount = bound(amount, 0, EXPECTED_SUPPLY);
        vm.prank(deployer);
        token.approve(spender, MAX);
        vm.prank(spender);
        assertTrue(token.transferFrom(deployer, alice, amount));
        assertEq(token.allowance(deployer, spender), MAX);
    }

    function testFuzz_infiniteAllowanceDoesNotBypassTheBalanceCheck(uint256 amount) public {
        amount = bound(amount, EXPECTED_SUPPLY + 1, MAX);
        vm.prank(deployer);
        token.approve(spender, MAX);
        vm.prank(spender);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, deployer, EXPECTED_SUPPLY, amount)
        );
        token.transferFrom(deployer, alice, amount);
        assertEq(token.balanceOf(deployer), EXPECTED_SUPPLY);
    }

    function testFuzz_allowanceDoesNotLetAStrangerPull(uint256 amount) public {
        amount = bound(amount, 1, EXPECTED_SUPPLY);
        vm.prank(deployer);
        token.approve(spender, amount);
        // Someone else, with the same arguments, is refused.
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, stranger, 0, amount));
        token.transferFrom(deployer, stranger, amount);
        assertEq(token.balanceOf(stranger), 0);
    }

    // ---------------------------------------------------------------------------------------------
    // Ether and calldata the token must refuse
    // ---------------------------------------------------------------------------------------------

    function testFuzz_noFunctionAcceptsEther(uint96 value, uint8 which) public {
        uint256 amount = uint256(bound(value, 1, type(uint96).max));
        bytes memory data;
        uint8 pick = which % 4;
        if (pick == 0) data = abi.encodeCall(IERC20.transfer, (alice, 0));
        else if (pick == 1) data = abi.encodeCall(IERC20.approve, (alice, 1));
        else if (pick == 2) data = abi.encodeCall(IERC20.transferFrom, (deployer, alice, 0));
        else data = abi.encodeCall(IERC20.totalSupply, ());

        vm.deal(deployer, amount);
        vm.prank(deployer);
        (bool ok,) = address(token).call{value: amount}(data);
        assertFalse(ok, "a call with ether succeeded");
        assertEq(address(token).balance, 0);
        assertEq(deployer.balance, amount, "ether left the caller");
        assertEq(token.balanceOf(alice), 0);
    }

    function testFuzz_undefinedSelectorsAreRejected(bytes4 selector, bytes calldata args) public {
        vm.assume(
            selector != IERC20.transfer.selector && selector != IERC20.transferFrom.selector
                && selector != IERC20.approve.selector && selector != IERC20.allowance.selector
                && selector != IERC20.balanceOf.selector && selector != IERC20.totalSupply.selector
                && selector != token.name.selector && selector != token.symbol.selector
                && selector != token.decimals.selector && selector != token.NAME.selector
                && selector != token.SYMBOL.selector && selector != token.DECIMALS.selector
                && selector != token.TOTAL_SUPPLY.selector
        );
        vm.prank(deployer);
        (bool ok,) = address(token).call(abi.encodePacked(selector, args));
        assertFalse(ok, "an undefined selector was accepted");
        assertEq(token.totalSupply(), EXPECTED_SUPPLY);
        assertEq(token.balanceOf(deployer), EXPECTED_SUPPLY);
    }

    function test_truncatedCalldataForDefinedFunctionsReverts() public {
        // transfer with the amount missing: ABI decoding must fail, nothing may move.
        vm.prank(deployer);
        (bool ok,) = address(token).call(abi.encodePacked(IERC20.transfer.selector, abi.encode(alice)));
        assertFalse(ok, "a truncated transfer call succeeded");
        assertEq(token.balanceOf(alice), 0);
    }
}

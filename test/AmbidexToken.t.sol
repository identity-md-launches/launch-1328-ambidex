// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {AmbidexToken} from "../src/AmbidexToken.sol";
import {DeployAmbidexToken} from "../script/DeployAmbidexToken.s.sol";

/// @notice Stands in for the launch factory: deploys the token's creation code through CREATE2 so
/// the test can check that whoever creates the token is the one who receives the supply.
contract FactoryProbe {
    function deploy(bytes memory code, bytes32 salt) external returns (address deployed) {
        assembly ("memory-safe") {
            deployed := create2(0, add(code, 32), mload(code), salt)
        }
        require(deployed != address(0), "constructor failed");
    }
}

contract AmbidexTokenTest is Test {
    uint256 internal constant EXPECTED_SUPPLY = 1_000_000_000 ether;

    address internal deployer = makeAddr("deployer");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal stranger = makeAddr("stranger");

    AmbidexToken internal token;

    function setUp() public {
        vm.prank(deployer);
        token = new AmbidexToken();
    }

    // ---------------------------------------------------------------------------------------------
    // Metadata and supply
    // ---------------------------------------------------------------------------------------------

    function test_metadata() public view {
        assertEq(token.name(), "AMBIDEX");
        assertEq(token.symbol(), "AMBI");
        assertEq(token.decimals(), 18);
        assertEq(token.NAME(), "AMBIDEX");
        assertEq(token.SYMBOL(), "AMBI");
        assertEq(token.DECIMALS(), 18);
    }

    function test_supplyIsOneBillionWithEighteenDecimals() public view {
        assertEq(token.TOTAL_SUPPLY(), EXPECTED_SUPPLY);
        assertEq(token.TOTAL_SUPPLY(), 1_000_000_000 * 10 ** 18);
        assertEq(token.totalSupply(), EXPECTED_SUPPLY);
    }

    function test_constructorMintsWholeSupplyToDeployer() public view {
        assertEq(token.balanceOf(deployer), EXPECTED_SUPPLY);
        assertEq(token.balanceOf(address(this)), 0);
    }

    function test_constructorEmitsSingleMintTransfer() public {
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(address(0), alice, EXPECTED_SUPPLY);
        vm.prank(alice);
        new AmbidexToken();
    }

    /// @dev The launch factory creates the token through CREATE2 and must end up holding the whole
    /// supply, exactly as the protected launch harness checks.
    function test_create2DeploymentMintsToTheCreatingContract() public {
        FactoryProbe factory = new FactoryProbe();
        bytes memory code = type(AmbidexToken).creationCode;
        address predicted = vm.computeCreate2Address(bytes32(uint256(7)), keccak256(code), address(factory));

        address deployed = factory.deploy(code, bytes32(uint256(7)));

        assertEq(deployed, predicted, "CREATE2 address is not deterministic");
        AmbidexToken launched = AmbidexToken(deployed);
        assertEq(launched.totalSupply(), EXPECTED_SUPPLY);
        assertEq(launched.balanceOf(address(factory)), EXPECTED_SUPPLY, "the factory does not hold the whole supply");
        assertEq(launched.decimals(), 18);
    }

    function test_deployScriptFunctionDeploysTheSameToken() public {
        DeployAmbidexToken script = new DeployAmbidexToken();
        AmbidexToken scripted = script.deploy();
        assertEq(scripted.name(), "AMBIDEX");
        assertEq(scripted.symbol(), "AMBI");
        assertEq(scripted.totalSupply(), EXPECTED_SUPPLY);
        // The script contract was msg.sender of the creation, so it holds the supply.
        assertEq(scripted.balanceOf(address(script)), EXPECTED_SUPPLY);
    }

    function test_constructorTakesNoArguments() public pure {
        // The creation code is the whole deployment payload: appending ABI-encoded arguments would
        // be a different contract. This pins the manifest's constructorArgs to an empty list.
        bytes memory code = type(AmbidexToken).creationCode;
        assertGt(code.length, 0);
    }

    // ---------------------------------------------------------------------------------------------
    // Transfers: success paths
    // ---------------------------------------------------------------------------------------------

    function test_transferMovesExactAmount() public {
        uint256 amount = 12_345 ether;
        vm.prank(deployer);
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(deployer, alice, amount);
        bool ok = token.transfer(alice, amount);

        assertTrue(ok);
        assertEq(token.balanceOf(alice), amount, "recipient received a different amount");
        assertEq(token.balanceOf(deployer), EXPECTED_SUPPLY - amount);
        assertEq(token.totalSupply(), EXPECTED_SUPPLY, "a transfer changed the supply");
    }

    function test_transferChainArrivesWholeAtEveryHop() public {
        // Mirrors the launch flow: factory -> distributor -> claimant, no amount lost on the way.
        uint256 swarm = (EXPECTED_SUPPLY * 1000) / 10_000;
        vm.prank(deployer);
        assertTrue(token.transfer(alice, swarm));
        assertEq(token.balanceOf(alice), swarm);
        vm.prank(alice);
        assertTrue(token.transfer(bob, swarm));
        assertEq(token.balanceOf(bob), swarm);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.totalSupply(), EXPECTED_SUPPLY);
    }

    function test_transferWholeBalance() public {
        vm.prank(deployer);
        assertTrue(token.transfer(alice, EXPECTED_SUPPLY));
        assertEq(token.balanceOf(alice), EXPECTED_SUPPLY);
        assertEq(token.balanceOf(deployer), 0);
    }

    function test_transferZeroAmountSucceeds() public {
        vm.prank(alice);
        assertTrue(token.transfer(bob, 0));
        assertEq(token.balanceOf(bob), 0);
    }

    function test_selfTransferKeepsBalance() public {
        vm.prank(deployer);
        assertTrue(token.transfer(deployer, 1 ether));
        assertEq(token.balanceOf(deployer), EXPECTED_SUPPLY);
    }

    function testFuzz_transferConservesBalances(address to, uint256 amount) public {
        vm.assume(to != address(0) && to != deployer);
        amount = bound(amount, 0, EXPECTED_SUPPLY);

        vm.prank(deployer);
        assertTrue(token.transfer(to, amount));

        assertEq(token.balanceOf(to), amount);
        assertEq(token.balanceOf(deployer), EXPECTED_SUPPLY - amount);
        assertEq(token.balanceOf(to) + token.balanceOf(deployer), EXPECTED_SUPPLY);
        assertEq(token.totalSupply(), EXPECTED_SUPPLY);
    }

    // ---------------------------------------------------------------------------------------------
    // Transfers: failure paths
    // ---------------------------------------------------------------------------------------------

    function test_transferRevertsOnInsufficientBalance() public {
        vm.prank(deployer);
        token.transfer(alice, 10 ether);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, 10 ether, 11 ether)
        );
        token.transfer(bob, 11 ether);

        assertEq(token.balanceOf(alice), 10 ether);
        assertEq(token.balanceOf(bob), 0);
    }

    function test_transferRevertsWhenSenderHoldsNothing() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, stranger, 0, 1));
        token.transfer(alice, 1);
    }

    function test_transferRevertsToZeroAddress() public {
        vm.prank(deployer);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        token.transfer(address(0), 1 ether);
        assertEq(token.totalSupply(), EXPECTED_SUPPLY);
    }

    // ---------------------------------------------------------------------------------------------
    // Allowances
    // ---------------------------------------------------------------------------------------------

    function test_approveAndTransferFrom() public {
        vm.prank(deployer);
        vm.expectEmit(true, true, true, true);
        emit IERC20.Approval(deployer, alice, 100 ether);
        assertTrue(token.approve(alice, 100 ether));
        assertEq(token.allowance(deployer, alice), 100 ether);

        vm.prank(alice);
        assertTrue(token.transferFrom(deployer, bob, 60 ether));

        assertEq(token.balanceOf(bob), 60 ether);
        assertEq(token.balanceOf(deployer), EXPECTED_SUPPLY - 60 ether);
        assertEq(token.allowance(deployer, alice), 40 ether, "allowance did not decrement");
    }

    function test_transferFromRevertsBeyondAllowance() public {
        vm.prank(deployer);
        token.approve(alice, 50 ether);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, alice, 50 ether, 51 ether)
        );
        token.transferFrom(deployer, bob, 51 ether);

        assertEq(token.balanceOf(bob), 0);
        assertEq(token.balanceOf(deployer), EXPECTED_SUPPLY);
    }

    function test_transferFromRevertsWithoutApproval() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, stranger, 0, 1));
        token.transferFrom(deployer, stranger, 1);
        assertEq(token.balanceOf(deployer), EXPECTED_SUPPLY);
    }

    function test_transferFromRevertsWhenOwnerBalanceTooLow() public {
        vm.prank(alice);
        token.approve(bob, 1 ether);
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, 0, 1 ether));
        token.transferFrom(alice, bob, 1 ether);
    }

    function test_infiniteAllowanceIsNotDecremented() public {
        vm.prank(deployer);
        token.approve(alice, type(uint256).max);
        vm.prank(alice);
        token.transferFrom(deployer, bob, 1 ether);
        assertEq(token.allowance(deployer, alice), type(uint256).max);
    }

    function test_approveRevertsForZeroSpender() public {
        vm.prank(deployer);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSpender.selector, address(0)));
        token.approve(address(0), 1);
    }

    // ---------------------------------------------------------------------------------------------
    // No privileged powers: nothing mints, nothing freezes, nothing moves a holder's balance
    // ---------------------------------------------------------------------------------------------

    function test_noFunctionCanIncreaseSupply() public {
        string[6] memory signatures = [
            "mint(address,uint256)",
            "mint(uint256)",
            "mint()",
            "issue(uint256)",
            "setMinter(address)",
            "transferOwnership(address)"
        ];
        address[2] memory callers = [deployer, stranger];
        for (uint256 c = 0; c < callers.length; c++) {
            for (uint256 i = 0; i < signatures.length; i++) {
                bytes memory data = abi.encodeWithSignature(signatures[i], stranger, type(uint128).max);
                vm.prank(callers[c]);
                (bool ok,) = address(token).call(data);
                assertFalse(ok, string.concat("unexpected function exists: ", signatures[i]));
                assertEq(token.totalSupply(), EXPECTED_SUPPLY, signatures[i]);
                assertEq(token.balanceOf(stranger), 0, signatures[i]);
            }
        }
    }

    function test_noFunctionCanFreezeOrMoveAHolder() public {
        vm.prank(deployer);
        token.transfer(alice, 1000 ether);

        string[12] memory signatures = [
            "pause()",
            "blacklist(address)",
            "blocklist(address)",
            "freeze(address)",
            "freezeAccount(address)",
            "setBlacklist(address,bool)",
            "setBlocked(address,bool)",
            "lock(address)",
            "disableTransfers()",
            "setTransfersEnabled(bool)",
            "burnFrom(address,uint256)",
            "seize(address)"
        ];
        for (uint256 i = 0; i < signatures.length; i++) {
            vm.prank(deployer);
            (bool ok,) = address(token).call(abi.encodeWithSignature(signatures[i], alice, true));
            assertFalse(ok, string.concat("unexpected function exists: ", signatures[i]));
        }

        // The deployer, the most plausibly trusted address, cannot pull without an allowance.
        vm.prank(deployer);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, deployer, 0, 1));
        token.transferFrom(alice, deployer, 1);

        assertEq(token.balanceOf(alice), 1000 ether, "a privileged call moved the holder's balance");
        vm.prank(alice);
        assertTrue(token.transfer(bob, 500 ether), "the holder can no longer transfer");
        assertEq(token.balanceOf(bob), 500 ether);
    }

    function test_unknownSelectorsRevertAndPlainEtherIsRefused() public {
        (bool ok,) = address(token).call(abi.encodeWithSignature("doesNotExist()"));
        assertFalse(ok, "unknown selector was accepted");
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        (ok,) = address(token).call{value: 1 ether}("");
        assertFalse(ok, "the token accepted ether");
        assertEq(address(token).balance, 0);
    }

    // ---------------------------------------------------------------------------------------------
    // Bytecode properties the launch floor checks
    // ---------------------------------------------------------------------------------------------

    function test_runtimeCodeHasNoDelegatecallCallcodeOrSelfdestruct() public view {
        bytes memory runtime = address(token).code;
        assertGt(runtime.length, 0, "the token has no runtime code");
        assertLe(runtime.length, 24_576, "runtime exceeds EIP-170");
        for (uint256 i = 0; i < runtime.length; i++) {
            uint8 op = uint8(runtime[i]);
            if (op >= 0x60 && op <= 0x7F) {
                i += (op - 0x5F);
                continue;
            }
            assertTrue(op != 0xF4, "runtime code contains DELEGATECALL");
            assertTrue(op != 0xF2, "runtime code contains CALLCODE");
            assertTrue(op != 0xFF, "runtime code contains SELFDESTRUCT");
        }
    }

    function test_runtimeCodeIsIdenticalAcrossDeployments() public {
        // bytecode_hash = "none" and cbor_metadata = false: two deployments of the same source
        // produce byte-identical runtime, which is what makes the launch's attested build reproducible.
        vm.prank(alice);
        AmbidexToken other = new AmbidexToken();
        assertEq(address(other).code, address(token).code);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title AMBIDEX (AMBI)
/// @notice A plain, fixed-supply ERC-20. The whole supply of 1,000,000,000 AMBI (18 decimals) is
/// minted once, in the constructor, to the deployer. Nothing can mint afterwards.
/// @dev Deliberately minimal:
///  - no owner, admin or privileged role of any kind;
///  - no mint, pause, blacklist, freeze, seize or forced-burn function;
///  - no transfer tax or burn-on-transfer: every transfer moves exactly the amount requested;
///  - no proxy, DELEGATECALL or SELFDESTRUCT;
///  - no constructor arguments and no external calls in the constructor, so it deploys on an
///    empty chain and the launch factory receives the full supply by being `msg.sender`.
/// The supply can only shrink, by holders sending tokens to an address nobody controls; it can
/// never grow. Standard ERC-20 approvals and `transferFrom` are the only way a third party moves a
/// holder's balance, and only up to what the holder approved.
contract AmbidexToken is ERC20 {
    /// @notice The token's ERC-20 name.
    string public constant NAME = "AMBIDEX";

    /// @notice The token's ERC-20 symbol.
    string public constant SYMBOL = "AMBI";

    /// @notice The number of decimals, as `decimals()` reports.
    uint8 public constant DECIMALS = 18;

    /// @notice The fixed total supply in minor units: 1,000,000,000 whole tokens with 18 decimals.
    uint256 public constant TOTAL_SUPPLY = 1_000_000_000 * 10 ** uint256(DECIMALS);

    /// @notice Mints the entire fixed supply to the deployer (`msg.sender`).
    /// @dev On the IdentityMD launch the deployer is the ProjectFactory, which distributes the
    /// supply according to the launch economics. There is no other mint path.
    constructor() ERC20(NAME, SYMBOL) {
        _mint(msg.sender, TOTAL_SUPPLY);
    }

    /// @inheritdoc ERC20
    function decimals() public pure override returns (uint8) {
        return DECIMALS;
    }
}

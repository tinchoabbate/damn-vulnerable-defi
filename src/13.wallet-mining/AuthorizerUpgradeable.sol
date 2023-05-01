// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title AuthorizerUpgradeable
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract AuthorizerUpgradeable is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    mapping(address => mapping(address => uint256)) private wards;

    event Rely(address indexed usr, address aim);

    function init(address[] memory _wards, address[] memory _aims) external initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();

        for (uint256 i = 0; i < _wards.length;) {
            _rely(_wards[i], _aims[i]);
            unchecked {
                i++;
            }
        }
    }

    function _rely(address usr, address aim) private {
        wards[usr][aim] = 1;
        emit Rely(usr, aim);
    }

    function can(address usr, address aim) external view returns (bool) {
        return wards[usr][aim] == 1;
    }

    function upgradeToAndCall(address imp, bytes memory wat) external payable override {
        _authorizeUpgrade(imp);
        _upgradeToAndCallUUPS(imp, wat, true);
    }

    function _authorizeUpgrade(address imp) internal override onlyOwner {}
}

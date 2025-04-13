// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract Nebula is Ownable {
    uint256 internal _nonce;
    mapping(address => string) internal _coinTypes;

    event TokenLocked(
        bytes32 indexed uid,
        string coinType,
        uint256 decimals,
        uint256 amount,
        bytes32 receiver
    );

    constructor() Ownable(msg.sender) {}

    function setCoinType(
        address token,
        string memory coinType
    ) external onlyOwner {
        _coinTypes[token] = coinType;
    }

    function lock(address token, uint256 amount, bytes32 receiver) external {
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        uint8 decimals = IERC20Metadata(token).decimals();
        _lock(token, amount, receiver, decimals);
    }

    function lockETH(bytes32 receiver) external payable {
        _lock(address(0), msg.value, receiver, 18);
    }

    function getNonce() external view returns (uint256) {
        return _nonce;
    }

    function getCoinType(address token) external view returns (string memory) {
        return _coinTypes[token];
    }

    function _lock(
        address token,
        uint256 amount,
        bytes32 receiver,
        uint8 decimals
    ) internal {
        emit TokenLocked(
            _getUID(token, amount, receiver),
            _coinTypes[token],
            decimals,
            amount,
            receiver
        );
        _nonce = _nonce + 1;
    }

    function _getUID(
        address token,
        uint256 amount,
        bytes32 receiver
    ) internal view returns (bytes32) {
        return keccak256(abi.encode(_nonce, token, amount, receiver));
    }
}

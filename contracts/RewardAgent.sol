// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/cryptography/SignatureCheckerUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interfaces/IRewardAgent.sol";
import "./TransferHelper.sol";
import "./Configable.sol";

contract RewardAgent is IRewardAgent, Configable, Initializable {
    address public signer;
    address public treasury;

    uint128 public totalCount;
    mapping(address => uint64) public userCounter;

    mapping(uint64 => bool) private _orders;
    
    function initialize(address signer_, address treasury_) external initializer {
        require(signer_ != address(0), 'Zero address');
        owner = msg.sender;
        signer = signer_;
        treasury = treasury_;
    }

    function setSigner(address signer_) external onlyDev {
        require(signer != signer_, 'There is no change');
        signer = signer_;
    }

    function setTreasury(address treasury_) external onlyDev {
        treasury = treasury_;
    }

    function claimERC20(
        address to,
        address token,
        uint256 amount,
        uint64 orderId,
        bytes memory signature
    ) external override returns(bool) {
        require(!_orders[orderId], "OrderId already exists");
        require(verifyClaimERC20(to, token, amount, orderId, signature), "Invalid signature");

        _orders[orderId] = true;
        userCounter[to] += 1;
        totalCount += 1;

        TransferHelper.safeTransferFrom(token, treasury, to, amount);

        emit SendERC20Reward(to, token, amount, orderId);
        return true;
    }

    function claimERC721(address, address, uint256, uint64, bytes memory) external pure override returns(bool) {
        // Extension
        return true;
    }

    function claimERC1155(address, address, uint256, uint256, uint64, bytes memory) external pure returns(bool) {
        // Extension
        return true;
    }

    function verifyClaimERC20(
        address to,
        address token,
        uint256 amount,
        uint256 orderId,
        bytes memory signature
    ) public view returns (bool) {
        bytes32 message = keccak256(abi.encodePacked(to, token, amount, orderId, address(this)));
        bytes32 hash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));
        return SignatureCheckerUpgradeable.isValidSignatureNow(signer, hash, signature);
    }
}
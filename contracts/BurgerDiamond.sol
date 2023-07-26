// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/SignatureCheckerUpgradeable.sol";
import "./Configable.sol";

contract BurgerDiamond is ERC20Upgradeable, Configable {
    address public signer;

    enum Operation {Claim, Exchange}

    mapping(uint256 => bool) private _orders;

    event Claim(address indexed receiver, uint256 amount, uint256 orderId, string txId);
    event Exchange(address indexed user, uint256 amount, uint256 contentId, string txId);

    function initialize(address signer_) external initializer {
        require(signer_ != address(0), "Signer can not be zero address");
        __ERC20_init("Burger Diamond", "BD");
        signer = signer_;
        owner = msg.sender;
    }

    function setSigner(address signer_) external onlyDev {
        require(signer != signer_, 'There is no change');
        signer = signer_;
    }

    function mint(address to, uint256 amount) external onlyDev {
        _mint(to, amount);
    }

    function claim(uint256 amount, uint256 orderId, string memory txId, bytes memory signature) external {
        require(!_orders[orderId], "OrderId already exists");
        require(verify(msg.sender, amount, orderId, txId, Operation.Claim, signature), "Invalid signature");

        _orders[orderId] = true;
        _mint(msg.sender, amount);

        emit Claim(msg.sender, amount, orderId, txId);
    }

    function exchange(uint256 amount, uint256 contentId, string memory txId, bytes memory signature) external {
        require(verify(msg.sender, amount, contentId, txId, Operation.Exchange, signature), "Invalid signature");

        _burn(msg.sender, amount);

        emit Exchange(msg.sender, amount, contentId, txId);
    }

    function verify(
        address user,
        uint256 amount,
        uint256 id,
        string memory txId,
        Operation operation,
        bytes memory signature
    ) public view returns (bool) {
        bytes32 message = keccak256(abi.encodePacked(user, amount, id, txId, operation, address(this)));
        bytes32 hash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));
        return SignatureCheckerUpgradeable.isValidSignatureNow(signer, hash, signature);
    }

    function decimals() public pure override returns(uint8) {
        return 0;
    }

    function orderIdExists(uint256 orderId) public view returns(bool) {
        return _orders[orderId];
    }
}
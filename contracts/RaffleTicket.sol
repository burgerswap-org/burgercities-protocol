// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "./Configable.sol";

contract RaffleTicket is ERC20, Configable {
    address public signer;

    mapping(uint64 => bool) private _orders;


    constructor(address signer_) ERC20("Raffle Ticket", "RT") {
        require(signer_ != address(0), "Signer can not be zero address");
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

    function claim(uint256 amount, uint64 orderId, bytes memory signature) external {
        require(!_orders[orderId], "OrderId already exists");
        require(verifyClaim(msg.sender, amount, orderId, signature), "Invalid signature");

        _mint(msg.sender, amount);
    }

    function verifyClaim(
        address to,
        uint256 amount,
        uint256 orderId,
        bytes memory signature
    ) public view returns (bool) {
        bytes32 message = keccak256(abi.encodePacked(to, amount, orderId, address(this)));
        bytes32 hash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));
        return SignatureChecker.isValidSignatureNow(signer, hash, signature);
    }

    function decimals() public pure override returns(uint8) {
        return 0;
    }
}
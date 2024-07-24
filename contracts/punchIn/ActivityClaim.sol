// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../lib/Signature.sol";
import "../Configable.sol";

contract ActivityClaim is Initializable, Configable {
    event PunchInEvent(address indexed user, uint256 timestamp);
    event Claim(address indexed user, uint256 timestamp, string txId);

    address private _signer;

    mapping(address => uint256) _userLastClaimTimestamps;

    function initialize(address signer) external initializer {
        owner = msg.sender;
        setConf(signer);
    }

    function setConf(address signer) public onlyDev {
        _signer = signer;
    }

    function claim(uint256 datetime, bytes memory signature, string memory txId) external {
        require(verify(msg.sender, datetime, txId, signature), "Invalid parameter signature");
        // require(datetime - _userLastClaimTimestamps[msg.sender] >= 86400, "Invalid parameter datetime");
        require(_userLastClaimTimestamps[msg.sender] < datetime, "Invalid parameter datetime");
        _userLastClaimTimestamps[msg.sender] = datetime;
        emit Claim(msg.sender, block.timestamp, txId);
    }

    function verify(
        address user,
        uint256 datetime,
        string memory txId,
        bytes memory signature
    ) public view returns (bool) {
        bytes32 message = keccak256(abi.encodePacked(user, datetime, txId, address(this)));
        bytes32 hash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));
        address[] memory signList = Signature.recoverAddresses(hash, signature);
        return signList[0] == _signer;
    }

    function userLastClaimTimestamps(address user) external view returns(uint256) {
        return _userLastClaimTimestamps[user];
    }
}
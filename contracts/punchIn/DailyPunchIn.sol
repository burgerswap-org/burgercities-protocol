// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../lib/openzeppelin/contracts/utils/math/SafeMath.sol";

contract DailyPunchIn {
    using SafeMath for uint256;

    struct UserInfo {
        uint256 lastTimestamp;
        uint256 amount;
    }

    uint256 public userTotalAmount;
    mapping(address => UserInfo) _userInfoes;

    event PunchInEvent(address user, uint256 timestamp);

    function punchIn() external {
        if (_userInfoes[msg.sender].amount == 0) {
            userTotalAmount = userTotalAmount.add((1));
        } else {
            require(block.timestamp.sub(_userInfoes[msg.sender].lastTimestamp) > 1 days, "Already punched in 1 day");
        }
        _userInfoes[msg.sender].amount = _userInfoes[msg.sender].amount.add(1);
        _userInfoes[msg.sender].lastTimestamp = block.timestamp;

        emit PunchInEvent(msg.sender, block.timestamp);
    }

    function userInfo(address user) external view returns (uint256, uint256) {
        return (_userInfoes[user].lastTimestamp, _userInfoes[user].amount);
    }
}

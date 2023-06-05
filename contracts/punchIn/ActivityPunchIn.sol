// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../lib/openzeppelin/contracts/utils/math/SafeMath.sol";
import "../lib/openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../lib/openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../Configable.sol";

contract ActivityPunchIn is Initializable, Configable {
    using SafeMath for uint256;

    struct Activity {
        uint256 startTimestamp;
        uint256 endTimestamp;
        uint256 limitAmount;
        uint256 rewardAmount;
        address rewardToken;
    }

    struct UserInfo {
        uint256 lastTimestamp;
        uint256 amount;
        bool isClaimed;
    }

    address private _treasury;
    Activity[] _activities;
    mapping(uint256 => mapping(address => UserInfo)) _activity2UserInfoes;
    mapping(uint256 => uint256) _activity2SuccessAmount;

    event CreateActivity(uint256 activityId, uint256 startTime, uint256 endTime, uint256 limitAmount);
    event UpdateActivity(uint256 activityId, uint256 rewardAmount, address rewardToken);
    event PunchInEvent(uint256 activityId, address user, uint256 timestamp);
    event Claim(uint256 activityId, address user, uint256 amount, address token);

    function initialize(address treasury) external initializer {
        _treasury = treasury;
        owner = msg.sender;
    }

    function setTreasury(address treasury) public onlyDev {
        require(treasury != _treasury , "No changed in treasury");
        _treasury = treasury;
    }

    function createActivity(
        uint256 startTimestamp,
        uint256 totalAmount,
        uint256 limitAmount,
        uint256 rewardAmount,
        address rewardToken
    ) external onlyDev {
        require(startTimestamp > block.timestamp , "Invalid parameter startTimestamp");
        require(totalAmount > 0, "Invalid parameter totaAmount");
        require(limitAmount <= totalAmount, "Invalid parameter limitAmount");
        require(rewardToken != address(0), "Invalid parameter rewardToken");

        uint256 endTimestamp = startTimestamp.add(totalAmount.mul(1 days));
        uint256 activityId = _activities.length;
        _activities.push(
            Activity(
                startTimestamp,
                endTimestamp,
                limitAmount,
                rewardAmount,
                rewardToken
            )
        );

        emit CreateActivity(activityId, startTimestamp, endTimestamp, limitAmount);
    }

    function updateActivity(uint256 activityId, uint256 rewardAmount, address rewardToken, uint256 limitAmount) external onlyDev {
        require(activityId < _activities.length, "Invalid parameter activityId");
        Activity storage activity = _activities[activityId];
        require(activity.endTimestamp > block.timestamp, "Activity has finished");
        require(rewardToken != address(0), "Invalid parameter rewardToken");
        if (limitAmount > activity.limitAmount) {
            require(activity.startTimestamp.add(limitAmount.mul(1 days)) < activity.endTimestamp, "Limit amount greater than total amount");
        }

        activity.rewardAmount = rewardAmount;
        activity.rewardToken = rewardToken;
        activity.limitAmount = limitAmount;

        emit UpdateActivity(activityId, rewardAmount, rewardToken);
    }

    function punchIn(uint256 activityId) external {
        require(activityId < _activities.length, "Invalid parameter activityId");
        Activity memory activity = _activities[activityId];
        require(activity.startTimestamp <= block.timestamp && activity.endTimestamp > block.timestamp, "Wrong time for activity");

        if (_activity2UserInfoes[activityId][msg.sender].lastTimestamp == 0) {
            // The first punch in.
            _activity2UserInfoes[activityId][msg.sender] = UserInfo(block.timestamp, 1, false);
        } else {
            // Not the first punch in.
            require(block.timestamp.sub(_activity2UserInfoes[activityId][msg.sender].lastTimestamp) > 1 days, "Already punched in 1 day");
            _activity2UserInfoes[activityId][msg.sender].lastTimestamp = block.timestamp;
            _activity2UserInfoes[activityId][msg.sender].amount = _activity2UserInfoes[activityId][msg.sender].amount.add(1);
        }

        // Check if the amount of user punch is equal to the limitAmount of activity.
        if (activity.limitAmount == _activity2UserInfoes[activityId][msg.sender].amount) {
            _activity2SuccessAmount[activityId] = _activity2SuccessAmount[activityId].add(1);
        }

        emit PunchInEvent(activityId, msg.sender, block.timestamp);
    }

    function claim(uint256 activityId, address to) external {
        require(activityId < _activities.length, "Invalid parameter activityId");
        Activity memory activity = _activities[activityId];
        require(activity.endTimestamp < block.timestamp, "The activity is ongoing");
        UserInfo storage userInfo_ = _activity2UserInfoes[activityId][msg.sender];
        require(userInfo_.amount >= activity.limitAmount, "The amount of user punch is less than limit amount");
        require(!userInfo_.isClaimed, "Already claimed");

        userInfo_.isClaimed = true;
        uint256 perRewardAmount = activity.rewardAmount.div(_activity2SuccessAmount[activityId]);
        IERC20(activity.rewardToken).transferFrom(_treasury, to, perRewardAmount);
        
        emit Claim(activityId, msg.sender, perRewardAmount, activity.rewardToken);
    }

    function activityLength() external view returns(uint256) {
        return _activities.length;
    }

    function activitySuccessAmount(uint256 activityId) external view returns(uint256) {
        require(activityId < _activities.length, "Invalid parameter activityId");
        return _activity2SuccessAmount[activityId];
    }

    function activityInfo(uint256 activityId) external view returns (Activity memory activity) {
        require(activityId < _activities.length, "Invalid parameter activityId");
        activity =  _activities[activityId];
    }

    function userInfo(uint256 activityId, address user) external view returns (uint256, uint256, bool) {
        require(activityId < _activities.length, "Invalid parameter activityId");
        UserInfo memory userInfo_ = _activity2UserInfoes[activityId][user];
        return (userInfo_.lastTimestamp, userInfo_.amount, userInfo_.isClaimed);
    }
}

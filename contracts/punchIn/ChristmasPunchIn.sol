// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../lib/openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../lib/openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../lib/openzeppelin/contracts/access/OwnableUpgradeable.sol";
import "../lib/Signature.sol";

contract ChristmasPunchIn is Initializable, OwnableUpgradeable {
    event PunchInEvent(address user, uint256 timestamp);
    event Claim(address user, uint256 timestamp);

    address public _treasury;
    address public _signer;
    address public _rewardToken;
    uint256 public _rewardAmount;

    mapping(address => uint64[]) _userTimestamps;
    mapping(address => bool) _userIsClaimed;

    function initialize(address treasury, address signer, address rewardToken, uint256 rewardAmount) external initializer {
       __ChristmasPunchIn_init(treasury, signer, rewardToken, rewardAmount);
    }

    function __ChristmasPunchIn_init(address treasury, address signer, address rewardToken, uint256 rewardAmount) internal onlyInitializing {
        __Ownable_init_unchained();
        setConf(treasury, signer, rewardToken, rewardAmount);
    }

    function setConf(address treasury, address signer, address rewardToken, uint256 rewardAmount) public onlyOwner {
        _treasury = treasury;
        _signer = signer;
        _rewardToken = rewardToken;
        _rewardAmount = rewardAmount;
    }

    function punchIn() external {
        _userTimestamps[msg.sender].push(uint64(block.timestamp));
        emit PunchInEvent(msg.sender, block.timestamp);
    }

    function claim(address to, bytes memory signature) external {
        require(verify(msg.sender, signature), "Invalid parameter signature");
        require(!_userIsClaimed[msg.sender], "User has already claimed");
        _userIsClaimed[msg.sender] = true;
        IERC20(_rewardToken).transferFrom(_treasury, to, _rewardAmount);

        emit Claim(msg.sender, block.timestamp);
    }

    function verify(
        address user,
        bytes memory signature
    ) public view returns (bool) {
        bytes32 message = keccak256(abi.encodePacked(user, address(this)));
        bytes32 hash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));
        address[] memory signList = Signature.recoverAddresses(hash, signature);
        return signList[0] == _signer;
    }
}
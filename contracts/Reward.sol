// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./lib/openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Configable.sol";
import "./TransferHelper.sol";

contract Reward is Configable {
    address public SIGNER;
    mapping(uint => mapping(uint => address)) public records;

    event Claimed(address indexed _user, uint indexed _group, uint indexed _rank, address _token, uint _amount);
    event Withdrawed(address indexed _user, address _token, uint _amount);
    event SignerChanged(address indexed _old, address indexed _new);

    receive() external payable {
    }

    constructor() {
        owner = msg.sender;
        SIGNER = msg.sender;
    }

    function _claim(uint _group, uint _rank, address _token, uint _amount, bytes memory _signatures) internal {
        require(records[_group][_rank] == address(0), 'claimed');
        require(verify(msg.sender, _group, _rank, _token, _amount, _signatures), 'invalid signatures');
        records[_group][_rank] = msg.sender;
        emit Claimed(msg.sender, _group, _rank, _token, _amount);
    }

    function claim(uint _group, uint _rank, address _token, uint _amount, bytes memory _signatures) external {
        _claim(_group, _rank, _token, _amount, _signatures);
        _withdraw(msg.sender, _token, _amount);
    }

    function batchClaim(address _token, uint[] calldata _groups, uint[] calldata _ranks, uint[] calldata _amounts, bytes[] calldata _signatures) external {
        require(_groups.length == _ranks.length && _groups.length == _amounts.length && _groups.length == _signatures.length, 'invalid parameters');
        uint _amount = 0;
        for(uint i=0; i<_amounts.length; i++) {
            _amount += _amounts[i];
            _claim(_groups[i], _ranks[i], _token, _amounts[i], _signatures[i]);
        }
        _withdraw(msg.sender, _token, _amount);
    }

    function withdraw(address _to, address _token, uint _amount) onlyOwner external {
        _withdraw(_to, _token, _amount);
        emit Withdrawed(_to, _token, _amount);
    }

    function _withdraw(address _to, address _token, uint _amount) internal returns (uint) {
        require(_amount > 0, 'zero');
        require(getBalance(_token) >= _amount, 'insufficient balance');

        if(_token == address(0)) {
            TransferHelper.safeTransferETH(_to, _amount);
        } else {
            TransferHelper.safeTransfer(_token, _to, _amount);
        }

        return _amount;
    }

    function getBalance(address _token) public view returns (uint) {
        if(_token == address(0)) {
            return address(this).balance;
        } else {
            return IERC20(_token).balanceOf(address(this));
        }
    }

    function updateSigner(address _new) external onlyAdmin {
        emit SignerChanged(SIGNER, _new);
        SIGNER = _new;
    }

    function verify(address _user, uint _group, uint _rank, address _token, uint _amount, bytes memory _signatures) public view returns (bool) {
        bytes32 message = keccak256(abi.encodePacked(_user, _group, _rank, _token, _amount, address(this)));
        bytes32 hash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));
        address[] memory signList = recoverAddresses(hash, _signatures);
        return signList[0] == SIGNER;
    }

    function recoverAddresses(bytes32 _hash, bytes memory _signatures) internal pure returns (address[] memory addresses) {
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint count = _countSignatures(_signatures);
        addresses = new address[](count);
        for (uint i = 0; i < count; i++) {
            (v, r, s) = _parseSignature(_signatures, i);
            addresses[i] = ecrecover(_hash, v, r, s);
        }
    }
    
    function _parseSignature(bytes memory _signatures, uint _pos) internal pure returns (uint8 v, bytes32 r, bytes32 s) {
        uint offset = _pos * 65;
        assembly {
            r := mload(add(_signatures, add(32, offset)))
            s := mload(add(_signatures, add(64, offset)))
            v := and(mload(add(_signatures, add(65, offset))), 0xff)
        }

        if (v < 27) v += 27;

        require(v == 27 || v == 28);
    }
    
    function _countSignatures(bytes memory _signatures) internal pure returns (uint) {
        return _signatures.length % 65 == 0 ? _signatures.length / 65 : 0;
    }
}
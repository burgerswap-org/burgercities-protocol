// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./lib/openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./Configable.sol";

contract Pay is Configable {
    IERC20 public burger20;
    uint32 public ver;
    address private SIGNER = 0x13a2032Ec8E6f8Def8338bBF86588aA5df4Ad2e6;

    event PayItem(address account, uint32 pay_id, uint price);

    constructor(address _burger20) {
        owner = msg.sender;
        burger20 = IERC20(_burger20);
        ver = 1;
    }

    function pay(uint32 _pay_id, uint _price, bytes memory _sign) external {
        require(verify(_pay_id, _price, _sign), "this sign is not valid");
        burger20.transferFrom(msg.sender, address(this), _price);
        emit PayItem(msg.sender, _pay_id, _price);
    }


    //*****************************************************************************
    //* inner
    //*****************************************************************************
    function verify(uint32 _pay_id, uint _price, bytes memory _signatures) public view returns (bool) {

        bytes32 message = keccak256(abi.encodePacked(address(this), _pay_id, _price, ver));
        bytes32 hash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));
        address[] memory sign_list = recoverAddresses(hash, _signatures);
        return sign_list[0] == SIGNER;
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

    function _countSignatures(bytes memory _signatures) internal pure returns (uint) {
        return _signatures.length % 65 == 0 ? _signatures.length / 65 : 0;
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

    //*****************************************************************************
    //* manage
    //*****************************************************************************
    function withdraw(address _to) external onlyAdmin
    {
        if (address(this).balance > 0) {
            payable(_to).transfer(address(this).balance);
        }
    }

    function withdrawBurger(address _to) external onlyAdmin
    {
        uint balance = burger20.balanceOf(address(this));
        if (balance > 0) {
            burger20.transfer(_to, balance);
        }
    }

    function setVer(uint32 _ver) external onlyAdmin {
        ver = _ver;
    }

    function balanceOfBurger() external view returns (uint)
    {
        return burger20.balanceOf(address(this));
    }

    function setBurger20(address _burger20) external onlyDev
    {
        require(_burger20 != address(0), "address should not 0");
        burger20 = IERC20(_burger20);
    }

    function setSigner(address _signer) external onlyDev {
        SIGNER = _signer;
    }



    function kill() external onlyOwner
    {
        uint balance = burger20.balanceOf(address(this));
        if (balance > 0) {
            burger20.transfer(owner, balance);
        }
        selfdestruct(payable(owner));
    }
}


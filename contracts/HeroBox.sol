// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./lib/openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./lib/openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./Common.sol";
import "./Configable.sol";

contract HeroBox is ReentrancyGuard, Configable {

    IHero721 public hero721;
    IERC20 public usdt20;

    uint public box_price = 100 ether;
    uint16 public creation_limit = 1000;

    event BuyBox(address buyer, uint price);

    constructor(address _hero721, address _usdt20)
    {
        owner = msg.sender;
        hero721 = IHero721(_hero721);
        usdt20 = IERC20(_usdt20);
    }

    function getHeroBoxInfo() external view returns (uint, uint)
    {
        return (box_price, creation_limit);
    }

    function buyCreationBox() external nonReentrant
    {
        if (box_price > 0) {
            usdt20.transferFrom(msg.sender, address(this), box_price);
        }

        _creationTo(msg.sender);

        emit BuyBox(msg.sender, box_price);
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

    function withdrawUSDT(address _to) external onlyAdmin
    {
        uint balance = usdt20.balanceOf(address(this));
        if (balance > 0) {
            usdt20.transfer(_to, balance);
        }
    }

    function balanceOfUSDT() external view returns (uint)
    {
        return usdt20.balanceOf(address(this));
    }

    function setBoxPrice(uint _price) external onlyAdmin
    {
        require(_price > 0, "box price should > 0");

        box_price = _price;
    }

    function creationTo(address _to, uint _amount) external onlyAdmin
    {
        require(_amount > 0,  "should > 0");
        for(uint i; i< _amount; i++) {
            _creationTo(_to);
        }
    }

    function setHero721(address _hero721) external onlyDev
    {
        require(_hero721 != address(0), "address should not 0");
        hero721 = IHero721(_hero721);
    }

    function setUSDT20(address _usdt20) external onlyDev
    {
        require(_usdt20 != address(0), "address should not 0");
        usdt20 = IERC20(_usdt20);
    }
    
    function addCreationLimit(uint16 _count) external onlyDev
    {
        require(_count > 0, "count should > 0");

        uint16 maxcnt = hero721.calcCreationLimit();
        creation_limit += _count;        
        require(creation_limit <= maxcnt, "creation_limit + count should <= maxcnt");
    }

    function setCreationLimit(uint16 _count) external onlyDev
    {
        uint16 maxcnt = hero721.calcCreationLimit();
        creation_limit = _count;
        require(creation_limit <= maxcnt, "creation_limit should <= maxcnt");
    }

    function kill() external onlyOwner
    {
        uint balance = usdt20.balanceOf(address(this));
        if (balance > 0) {
            usdt20.transfer(owner, balance);
        }
        selfdestruct(payable(owner));
    }

    function _creationTo(address _to) internal
    {
        require(creation_limit > 0, "empty box");

        HeroMetaData memory meta;
        meta.opened = false;
        meta.gen = 0;

        hero721.createCreationTo(_to, meta);
        creation_limit--;
    }
}
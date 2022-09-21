// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../Common.sol";

contract TestHeroBox {
    IHero721 public hero721;

    constructor(address _hero721) {
        hero721 = IHero721(_hero721);
    }

    function buyCreationBox(uint amount, address to) external {
        for (uint i = 0; i < amount; i++) {
            _creationTo(to);
        }
    }

    function _creationTo(address _to) internal {
        HeroMetaData memory meta;
        meta.opened = false;
        meta.gen = 0;
        hero721.createCreationTo(_to, meta);
    }
}

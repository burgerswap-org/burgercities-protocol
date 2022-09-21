import { Wallet, BigNumber } from 'ethers'
import { ethers, waffle } from 'hardhat'
import { TestERC721 } from '../typechain/TestERC721'
import { TestHeroBox } from '../typechain/TestHeroBox'
import { Hero721 } from '../typechain/Hero721'
import { HeroExchange } from '../typechain/HeroExchange'
import { expect } from './shared/expect'
import { heroExchangeFixture, signHeroExchange } from './shared/fixtures'

const createFixtureLoader = waffle.createFixtureLoader

describe('HeroExchange', async () => {
  let wallet: Wallet, other: Wallet, user: Wallet;

  let nft0: TestERC721
  let nft1: Hero721
  let heroBox: TestHeroBox
  let heroExchange: HeroExchange

  let loadFixTure: ReturnType<typeof createFixtureLoader>;

  before('create fixture loader', async () => {
    [wallet, other, user] = await (ethers as any).getSigners()
    loadFixTure = createFixtureLoader([wallet])
  })

  beforeEach('deploy HeroExchange', async () => {
    ; ({ nft0, nft1, heroBox, heroExchange } = await loadFixTure(heroExchangeFixture));
    await nft0.mint(BigNumber.from(10), other.address)
    await heroBox.buyCreationBox(BigNumber.from(10), wallet.address)
    await nft1.setApprovalForAll(heroExchange.address, true)
  })

  it('check state', async () => {
    expect(await nft0.balanceOf(other.address)).to.eq(BigNumber.from(10))
    expect(await nft0.ownerOf(BigNumber.from(1))).to.eq(other.address)
    expect(await nft1.balanceOf(wallet.address)).to.eq(BigNumber.from(10))
    expect(await nft1.ownerOf(BigNumber.from(1))).to.eq(wallet.address)
  })

  describe('#exchange', async () => {
    it('success for user exchange', async () => {
      let tokenId0 = BigNumber.from(1)
      await nft0.connect(other).transferFrom(other.address, user.address, tokenId0)
      await nft0.connect(user).approve(heroExchange.address, tokenId0)
      let tokenId1 = BigNumber.from(1)
      let signature = await signHeroExchange(wallet, tokenId0.toString(), tokenId1.toString(), heroExchange.address)
      await heroExchange.connect(user).exchange(tokenId0, tokenId1, signature)
      expect(await nft0.ownerOf(tokenId0)).to.eq(heroExchange.address)
      expect(await nft1.ownerOf(tokenId1)).to.eq(user.address)
    })
  })
})
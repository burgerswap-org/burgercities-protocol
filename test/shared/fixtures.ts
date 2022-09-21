import { Wallet } from 'ethers'
import { ethers, network } from 'hardhat'
import { TestERC721 } from '../../typechain/TestERC721'
import { TestHeroBox } from '../../typechain/TestHeroBox'
import { Hero721 } from '../../typechain/Hero721'
import { HeroExchange } from '../../typechain/HeroExchange'
import { Fixture } from 'ethereum-waffle'

async function testERC721(): Promise<TestERC721> {
    let factory = await ethers.getContractFactory('TestERC721')
    let token = (await factory.deploy()) as TestERC721
    return token
}

interface HeroFixture {
    hero721: Hero721
    heroBox: TestHeroBox
}

async function hero(): Promise<HeroFixture> {
    let factory = await ethers.getContractFactory('Hero721')
    let hero721 = (await factory.deploy()) as Hero721
    let boxFactory = await ethers.getContractFactory('TestHeroBox')
    let heroBox = (await boxFactory.deploy(hero721.address)) as TestHeroBox
    await hero721.setHeroBox(heroBox.address)

    return { hero721, heroBox }
}

interface HeroExchangeFixture {
    nft0: TestERC721
    nft1: Hero721
    heroBox: TestHeroBox
    heroExchange: HeroExchange
}

export const heroExchangeFixture: Fixture<HeroExchangeFixture> = async function ([wallet]: Wallet[]): Promise<HeroExchangeFixture> {
    let nft0 = await testERC721()
    let { hero721: nft1, heroBox } = await hero()

    let factory = await ethers.getContractFactory('HeroExchange')
    let heroExchange = (await factory.deploy(wallet.address, nft0.address, nft1.address, wallet.address)) as HeroExchange

    return { nft0, nft1, heroBox, heroExchange }
}

async function signHeroExchange(
    wallet: Wallet,
    tokenId0: string,
    tokenId1: string,
    addr: string
): Promise<string> {
    let types = ['uint256', 'uint256', 'address']
    let values = [tokenId0, tokenId1, addr]
    let message = ethers.utils.solidityKeccak256(types, values)
    let s = await network.provider.send('eth_sign', [wallet.address, message])
    return s;
}

export { signHeroExchange }
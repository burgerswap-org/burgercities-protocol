import { BigNumber, Wallet } from 'ethers'
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

export const heroExchangeFixture: Fixture<HeroExchangeFixture> = async function ([wallet, other]: Wallet[]): Promise<HeroExchangeFixture> {
    let nft0 = await testERC721()
    let { hero721: nft1, heroBox } = await hero()
    let factory = await ethers.getContractFactory('HeroExchange')
    let heroExchange = (await factory.deploy(wallet.address, nft0.address, nft1.address, wallet.address)) as HeroExchange
    let blueTokenIds = []
    for (let i = 1; i <= 700; i++) {
        blueTokenIds.push(i)
    }
    let tx = await heroExchange.setTokenIds(BigNumber.from(0), blueTokenIds)
    let receipt = await tx.wait()
    console.log("gas used: ", receipt.gasUsed.toString())
    let purpleTokenIds = []
    for (let i = 701; i <= 900; i++) {
        purpleTokenIds.push(i)
    }
    await heroExchange.setTokenIds(BigNumber.from(1), purpleTokenIds)
    let orangeTokenIds = []
    for (let i = 901; i <= 1000; i++) {
        orangeTokenIds.push(i)
    }
    await heroExchange.setTokenIds(BigNumber.from(2), orangeTokenIds)

    await nft0.mint(BigNumber.from(10), other.address)
    for (let i = 0; i < 5; i++) {
      await heroBox.buyCreationBox(BigNumber.from(200), wallet.address)
    }
    await nft1.setApprovalForAll(heroExchange.address, true)

    return { nft0, nft1, heroBox, heroExchange }
}

async function signHeroExchange(
    wallet: Wallet,
    tokenId0: string,
    quality: string,
    addr: string
): Promise<string> {
    let types = ['uint256', 'uint8', 'address']
    let values = [tokenId0, quality, addr]
    let message = ethers.utils.solidityKeccak256(types, values)
    let s = await network.provider.send('eth_sign', [wallet.address, message])
    return s;
}

async function signHeroBatchExchange(
    wallet: Wallet,
    tokenId0s: any,
    qualities: any,
    addr: string
): Promise<string> {
    let types = ['uint256[]', 'uint8[]', 'address']
    let values = [tokenId0s, qualities, addr]
    let message = ethers.utils.solidityKeccak256(types, values)
    let s = await network.provider.send('eth_sign', [wallet.address, message])
    return s;
}

export { signHeroExchange, signHeroBatchExchange }
import { BigNumber, Wallet } from 'ethers'
import { ethers, network } from 'hardhat'
import { MerkleTree } from 'merkletreejs'
import { TestERC721 } from '../../typechain/TestERC721'
import { TestHeroBox } from '../../typechain/TestHeroBox'
import { Hero721 } from '../../typechain/Hero721'
import { HeroExchange } from '../../typechain/HeroExchange'
import { HeroAirdrop } from '../../typechain/HeroAirdrop'
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

interface HeroAirdropFixture {
    nft0: TestERC721
    heroAirdrop: HeroAirdrop
    tokenIds: Array<number>
    whitelist: Array<string>
}

export const heroAirdropFixture: Fixture<HeroAirdropFixture> = async function ([wallet, other]: Wallet[]): Promise<HeroAirdropFixture> {
    let nft0 = await testERC721()
    let amount = 10
    await nft0.mint(amount, wallet.address)
    let tokenIds = []
    for (let i = 1; i <= amount; i++) {
        tokenIds.push(i)
    }
    let whitelist = [
        wallet.address,
        other.address,
        "0x3beBB78b729E1683649A58eb30ad000Ee2bD2bE4",
        "0x7Fcb25CbbA952acC9eCF661A36A9EAd7251F33c2",
        "0x1D7523dC020A3f68985151AeAD21b39c94D54ad0",
        "0x447eC497E2cB07DC8E349bfbD7ef86379e58fD50",
        "0x0191ebb6374663cA1C7eEAF09054c2773c5B4D9B",
        "0x4a60b3c4705c0818e8C5363a52b4bFd92DBA65d2",
        "0xb584659516a2b660F989e825319e027816bD13cf",
        "0x0D0BF9f41437c114078E7EB787A2ce29286a19Ae"
    ]
    let mt = await makeMerkleTree(whitelist)
    let heroAirdropFactory = await ethers.getContractFactory("HeroAirdrop")
    let heroAirdrop = (await heroAirdropFactory.deploy(nft0.address, wallet.address, mt.rootHash, tokenIds)) as HeroAirdrop
    await nft0.connect(wallet).setApprovalForAll(heroAirdrop.address, true)
    return { nft0, heroAirdrop, tokenIds, whitelist }
}

export const signHeroExchange = async function (
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

export const signHeroBatchExchange = async function (
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

export const makeMerkleTree = async function (whitelist: Array<string>): Promise<{ tree: MerkleTree, rootHash: string }> {
    let leafs = []
    for (let i = 0; i < whitelist.length; i++) {
        let leafHash = ethers.utils.solidityKeccak256(['address'], [whitelist[i]])
        leafs.push(leafHash)
    }
    let tree = new MerkleTree(leafs, ethers.utils.keccak256, { sortPairs: true })
    let rootHash = tree.getHexRoot()
    return { tree: tree, rootHash: rootHash }
}

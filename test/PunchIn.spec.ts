import { Wallet, BigNumber } from 'ethers'
import { ethers, waffle } from 'hardhat'
import { TestERC20 } from '../typechain/TestERC20'
import { PunchIn } from '../typechain/PunchIn'
import { expect } from './shared/expect'
import { punchInFixture } from './shared/fixtures'

const createFixtureLoader = waffle.createFixtureLoader

describe('PunchIn', async () => {
  let wallet: Wallet, otherA: Wallet, otherB: Wallet;

  let rewardToken: TestERC20
  let punchIn: PunchIn

  let loadFixTure: ReturnType<typeof createFixtureLoader>;

  before('create fixture loader', async () => {
    [wallet, otherA, otherB] = await (ethers as any).getSigners()
    loadFixTure = createFixtureLoader([wallet])
  })

  beforeEach('deploy PunchIn', async () => {
    ; ({ rewardToken, punchIn } = await loadFixTure(punchInFixture));
  })

  it('check state', async () => {
    expect(await rewardToken.totalSupply()).to.eq(BigNumber.from(10000))
    expect(await punchIn.owner()).to.eq(wallet.address)
  })

  describe('#createActivity', async () => {
    it('success',async () => {
      let startTimestamp = BigNumber.from(Date.now()).div(1000)
      let totalAmount = BigNumber.from(3)
      let limitAmount = BigNumber.from(2)
      let rewardAmount = BigNumber.from(100)
      await punchIn.createActivity(startTimestamp, totalAmount, limitAmount, rewardAmount, rewardToken.address)
      expect(await punchIn.activityLength()).to.eq(1)
    })
  })
})
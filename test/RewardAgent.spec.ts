import { Wallet, BigNumber } from 'ethers'
import { ethers, waffle } from 'hardhat'
import { TestERC20 } from '../typechain/TestERC20'
import { RewardAgent } from '../typechain/RewardAgent'
import { RaffleTicket } from '../typechain/RaffleTicket'
import { expect } from './shared/expect'
import { rewardAgentFixture, signRewardAgentClaimERC20, signRaffleTicketClaim } from './shared/fixtures'

const createFixtureLoader = waffle.createFixtureLoader

describe('RewardAgent', async () => {
  let wallet: Wallet, otherA: Wallet;

  let rewardToken: TestERC20
  let rewardAgent: RewardAgent
  let raffleTicket: RaffleTicket

  let loadFixTure: ReturnType<typeof createFixtureLoader>;

  before('create fixture loader', async () => {
    [wallet, otherA] = await (ethers as any).getSigners()
    loadFixTure = createFixtureLoader([wallet])
  })

  beforeEach('deploy instance', async () => {
    ; ({ rewardToken, rewardAgent, raffleTicket } = await loadFixTure(rewardAgentFixture));
    await rewardToken.mint(wallet.address, BigNumber.from(10000))
    await rewardToken.approve(rewardAgent.address, ethers.constants.MaxUint256)
  })

  it('check state', async () => {
    expect(await rewardAgent['signer()']()).to.eq(wallet.address)
    expect(await rewardAgent.treasury()).to.eq(wallet.address)
    expect(await raffleTicket.decimals()).to.eq(0)
  })

  describe('#claimERC20', async () => {
    it('success', async () => {
      // Claim rallfle ticket
      let claimAmountRT = BigNumber.from(100)
      let orderIdRT = BigNumber.from(123)
      let txIdRT = BigNumber.from(123)
      let signatureRT = await signRaffleTicketClaim(wallet, otherA.address, claimAmountRT.toString(), orderIdRT.toString(), raffleTicket.address)
      await raffleTicket.connect(otherA).claim(claimAmountRT, orderIdRT, txIdRT, signatureRT)
      expect(await raffleTicket.balanceOf(otherA.address)).to.eq(claimAmountRT)

      // Exchange raffle ticket
      let exchangedAmountRT = BigNumber.from(10)
      await raffleTicket.connect(otherA).exchange(exchangedAmountRT)
      expect(await raffleTicket.balanceOf(otherA.address)).to.eq(claimAmountRT.sub(exchangedAmountRT))

      // Claim reward
      let rewardAmountRA = BigNumber.from(100)
      let orderIdRA = BigNumber.from(456)
      let txIdRA = BigNumber.from(456)
      let signatureRA = await signRewardAgentClaimERC20(
        wallet,
        otherA.address,
        rewardToken.address,
        rewardAmountRA.toString(),
        orderIdRA.toString(),
        rewardAgent.address
      )
      await rewardAgent.claimERC20(otherA.address, rewardToken.address, rewardAmountRA, orderIdRA, txIdRA, signatureRA)
      expect(await rewardToken.balanceOf(otherA.address)).to.eq(rewardAmountRA)
    })
  })
})
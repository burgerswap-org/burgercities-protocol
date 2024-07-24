import { Wallet, BigNumber } from 'ethers'
import { ethers, network, waffle } from 'hardhat'
import { ActivityClaim } from '../typechain/ActivityClaim'
import { expect } from './shared/expect'
import { activityClaimFixture, signActivityClaim } from './shared/fixtures'

const createFixtureLoader = waffle.createFixtureLoader

describe('Activity', async () => {
  let wallet: Wallet, otherA: Wallet, otherB: Wallet;

  let activityClaim: ActivityClaim
  let txId = "test-dev"

  let loadFixTure: ReturnType<typeof createFixtureLoader>;

  before('create fixture loader', async () => {
    [wallet, otherA, otherB] = await (ethers as any).getSigners()
    loadFixTure = createFixtureLoader([wallet])
  })

  beforeEach('deploy PunchIn', async () => {
    ; ({ activityClaim } = await loadFixTure(activityClaimFixture));
  })

  describe('#claim', async () => {
    it('success for first time', async () => {
      let datetime = BigNumber.from(Date.now()).div(1000).toString()
      let signature = await signActivityClaim(wallet, otherA.address, datetime, txId, activityClaim.address)
      await activityClaim.connect(otherA).claim(datetime, signature, txId)
      expect(await activityClaim.userLastClaimTimestamps(otherA.address)).to.gt(0)
    })

    it('failed for same datetime', async () => {
      let datetime = BigNumber.from(Date.now()).div(1000)
      let signature = await signActivityClaim(wallet, otherA.address, datetime.toString(), txId, activityClaim.address)
      await activityClaim.connect(otherA).claim(datetime, signature, txId)
      let newSignature = await signActivityClaim(wallet, otherA.address, datetime.toString(), txId, activityClaim.address)
      await expect(activityClaim.connect(otherA).claim(datetime.toString(), newSignature, txId)).revertedWith("Invalid parameter datetime")
    })

    it('success for claim second day', async () => {
      let datetime = BigNumber.from(Date.now()).div(1000)
      let signature = await signActivityClaim(wallet, otherA.address, datetime.toString(), txId, activityClaim.address)
      await activityClaim.connect(otherA).claim(datetime, signature, txId)
      let userLastClaimTimestamp = await activityClaim.userLastClaimTimestamps(otherA.address)
      let newDateTime = datetime.add(86400)
      let newSignature = await signActivityClaim(wallet, otherA.address, newDateTime.toString(), txId, activityClaim.address)
      await activityClaim.connect(otherA).claim(newDateTime.toString(), newSignature, txId)
      expect(await activityClaim.userLastClaimTimestamps(otherA.address)).to.gt(userLastClaimTimestamp)
    })
  })
})
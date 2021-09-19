import { expect } from "chai";
import { deployments, ethers } from "hardhat";
import { VanityNames } from "../typechain/VanityNames";
import {ONE_ETHER} from './constants';

describe("Vanity names tests", function () {
  beforeEach(async () => deployments.fixture());

  it("should book and buy a string, also it should block other users from buying the same string", async function () {
    const [deployer, firstTestWallet, secondTestWallet] = await ethers.getSigners();

    const vanityNames = await ethers.getContract("VanityNames") as VanityNames;

    const randomNumber = 1856;
    const stringForHashing = 'test string';
    const initialBalance = await ethers.provider.getBalance(firstTestWallet.address);

    const encodedString = ethers.utils.sha256(
      ethers.utils.defaultAbiCoder.encode([ "string", "uint" ], [ stringForHashing, randomNumber ])
    );

    const bookValuePrice = (await vanityNames.connect(firstTestWallet).namePricePerByte()).mul(32);
    const buyValuePrice = await vanityNames.connect(firstTestWallet).getNamePrice(stringForHashing);

    await (await vanityNames.connect(firstTestWallet).bookName(encodedString, { value: ONE_ETHER })).wait();

    const balanceAfterBooking = await ethers.provider.getBalance(firstTestWallet.address);
    expect(balanceAfterBooking.toString()).to.equals(initialBalance.sub(bookValuePrice).toString());

    await expect(
      vanityNames.connect(secondTestWallet).bookName(encodedString, { value: ONE_ETHER })
    ).to.be.revertedWith("Name is already bought");

    await (
      await vanityNames.connect(firstTestWallet).revealName(stringForHashing, randomNumber, encodedString, { value: ONE_ETHER })
    ).wait();


    const balanceAfterBuying = await ethers.provider.getBalance(firstTestWallet.address);
    expect(balanceAfterBuying.toString()).to.equals(initialBalance.sub(buyValuePrice).toString());


    expect((await vanityNames.connect(firstTestWallet).getNameOwner(stringForHashing)).toString())
      .to.equals(firstTestWallet.address);


    expect((await vanityNames.connect(firstTestWallet).getExpirationBlock(stringForHashing)).toString())
      .to.equals('30000');
  });

});

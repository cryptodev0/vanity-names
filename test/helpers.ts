import {BigNumberish, ethers} from 'ethers';

export const convertBigNumber = (bnAmount: number, divider: BigNumberish) => {
  return ethers.BigNumber.from(bnAmount.toString()).div(divider).toString();
}


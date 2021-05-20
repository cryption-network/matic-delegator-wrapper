// require("dotenv").config();
const chai = require("chai");
const chaiAsPromised = require("chai-as-promised");

chai.use(chaiAsPromised);
const { ethers } = require("hardhat");
const { advanceBlockTo } = require("./utilities/time.js");
const MasterchefAbi = require('../artifacts/contracts/MasterChef.sol/MasterChef.json');
const ERC20Abi = require('../artifacts/@openzeppelin/contracts/token/ERC20/ERC20.sol/ERC20.json');
const TransferProof = require('./proof.json');

const Addresses = require('./address.json');

describe("MasterChef", function () {
  before(async function () {

    const walletAddress = process.env.privateKey; // Set in env variables

    this.provider = new ethers.providers.JsonRpcProvider();
    this.wallet = await new ethers.Wallet(walletAddress, this.provider);

  });

  beforeEach(async function () {

    this.validatorSharesInstance = await new ethers.Contract(
      Addresses.validatorShareLPToken,
      ERC20Abi.abi,
      this.provider,
    );

    this.masterChefInstance = await new ethers.Contract(
      Addresses.masterChefAddress,
      MasterchefAbi.abi,
      this.provider
    );

  });

  context("With Validator shares deposit and withdraw", function () {

    it("should successfully deposit or withdraw", async function () {
      this.masterChefInstance = await new ethers.Contract(
        Addresses.masterChefAddress,
        MasterchefAbi.abi,
        this.provider
      );

      const masterChefReceipt = await this.masterChefInstance.connect(this.wallet).deposit(
        TransferProof.blockHash,
        TransferProof.rlpBlock,
        TransferProof.rlpEncodedReceipt,
        TransferProof.path,
        TransferProof.witness,
        2,
        TransferProof.receiptsRoot,
      );

      const beforeMasterChefBalance = await this.validatorSharesInstance.balanceOf(Addresses.masterChefAddress);

      const connectedWallet = this.masterChefInstance.connect(this.wallet);
      await connectedWallet.withdraw("100");
      const afterMasterChefBalance = await this.validatorSharesInstance.balanceOf(Addresses.masterChefAddress);
    });


    it("should fail when receipts root is submitted twice ", async function () {

      await chai.expect(this.masterChefInstance.connect(this.wallet).deposit(
        TransferProof.blockHash,
        TransferProof.rlpBlock,
        TransferProof.rlpEncodedReceipt,
        TransferProof.path,
        TransferProof.witness,
        2,
        TransferProof.receiptsRoot,
      )
      ).to.eventually.be.rejectedWith(Error);
    });
    });
});

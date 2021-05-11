const CachingProvider = require('./CachingProvider');

const { GetProof } = require('eth-proof');
const { ethers } = require("ethers");
const { BigNumber, RLP } = require("ethers/utils");

// TODO: Move to constants file
const jsonRpcUrl = 'https://goerli.infura.io/v3/0b3c6bddd7d14140a0640806a04c2d49'; // replace with rpc endpoint

const prover = new GetProof(jsonRpcUrl);
const provider = new CachingProvider(new ethers.providers.JsonRpcProvider(jsonRpcUrl));

class ValidatorShareProof {

  static async getReceiptProof(txHash, blockNumber) {
    const block = await provider.performTask("getBlock", { blockTag: new BigNumber(blockNumber).toHexString() });

    const pr = await prover.receiptProof(txHash);

    const receiptProof = ValidatorShareProof.prepareReceiptProof(pr);

    const rlpBlock = ValidatorShareProof.rlpEncodedBlock(block);
    // console.log('block : ',block);
    return {
      blockHash: block.hash,
      receiptsRoot: block.receiptsRoot,
      rlpBlock,
      rlpEncodedReceipt: receiptProof.rlpEncodedReceipt,
      path: receiptProof.path,
      witness: receiptProof.witness,
    };

  }

  static prepareReceiptProof(proof) {
    // the path is HP encoded
    console.log('proof.txIndex :', proof.txIndex);
    const indexBuffer = proof.txIndex.slice(2);
    console.log('indexBuffer :', indexBuffer.toString(16));

    const hpIndex = "0x" + (indexBuffer.startsWith("0") ? "1" + indexBuffer.slice(1) : "00" + indexBuffer);

    // the value is the second buffer in the leaf (last node)
    const value = "0x" + Buffer.from(proof.receiptProof[proof.receiptProof.length - 1][1]).toString("hex");
    // the parent nodes must be rlp encoded
    const parentNodes = RLP.encode(proof.receiptProof);

    return {
      path: hpIndex,
      rlpEncodedReceipt: value,
      witness: parentNodes
    };
  }

  static rlpEncodedBlock(block) {
    const selectedBlockElements = [
      block.parentHash,
      block.sha3Uncles,
      block.miner,
      block.stateRoot,
      block.transactionsRoot,
      block.receiptsRoot,
      block.logsBloom,
      block.difficulty,
      block.number,
      block.gasLimit,
      block.gasUsed === "0x0" ? "0x" : block.gasUsed,
      block.timestamp,
      block.extraData,
      block.mixHash,
      block.nonce
    ];

    return RLP.encode(selectedBlockElements);
  }
}



ValidatorShareProof.getReceiptProof('0x850222b8725f17b3d3ce7aa00ff6e66d747be6092e3c7d2febfded6beef5e779', '4772713').then((value) => {
  console.log('value ', value);
}).catch((err) => {
  console.log('err ', err);
});


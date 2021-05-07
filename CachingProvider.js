const { ethers } = require("ethers");
// import * as LevelUp from "levelup";
const LevelUp = require('levelup');
const LevelDOWN = require("leveldown");
const EncodingDown = require("encoding-down");

class CachingProvider extends ethers.providers.BaseProvider {
  // db;

  constructor(baseProvider) {
    super(1);
    this.db = LevelUp.default(EncodingDown(LevelDOWN("db"), { valueEncoding: "json" }));
    this.baseProvider = baseProvider;
  }

  async performTask(method, params) {
    const key = `${method}:${JSON.stringify(params)}`;
    try {
      return await this.db.get(key);
    } catch (doh) {
      const basePerfom = await this.baseProvider.perform(method, params);
      await this.db.put(key, basePerfom);
      return basePerfom;
    }
  }
}

module.exports = CachingProvider;
// SPDX-License-Identifier: MIT

pragma solidity 0.7.0;

// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
// import "@openzeppelin/contracts/math/SafeMath.sol";
// import "./library/TransferHelper.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";

import './mocks/CryptionNetworkToken.sol';
import './lib/EventProof.sol';
import './lib/RLPReader.sol';

contract Farm01 is Ownable{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using RLPReader for bytes;
    using RLPReader for RLPReader.RLPItem;

    /// @notice information stuct on each user than stakes LP tokens.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt.
    }
    
    /// @notice all the settings for this farm in one struct
    struct FarmInfo {
        IERC20 lpToken;
        IERC20 rewardToken;
        uint256 startBlock;
        uint256 blockReward;
        uint256 bonusEndBlock;
        uint256 bonus;
        uint256 endBlock;
        uint256 lastRewardBlock;  // Last block number that reward distribution occurs.
        uint256 accRewardPerShare; // Accumulated Rewards per share, times 1e12
        uint256 farmableSupply; // set in init, total amount of tokens farmable
        uint256 numFarmers;
    }
    
    /// @notice farm type id. Useful for back-end systems to know how to read the contract (ABI) 
    /// as we plan to launch multiple farm types
    uint256 public farmType = 1;
   
    address public farmGenerator;

    FarmInfo public farmInfo;
    
    /// @notice information on each user than stakes LP tokens
    mapping (address => UserInfo) public userInfo;

    // Receipts root vs bool. It is used to avoid same tx submission twice.
    mapping (bytes32 => bool) public receipts;

    uint256 public constant EVENT_INDEX_IN_RECEIPT = 3; 
    uint256 public TRANSFER_EVENT_PARAMS_INDEX_IN_RECEIPT = 1;

    bytes32 public constant TRANSFER_EVENT_SIG = 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef;

    address CRYPTION_VALIDATOR_SHARE_PROXY_CONTRACT = address(0x44d2c14F79EF400D6AF53822a054945704BF1FeA);

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);

    constructor( address _farmGenerator) public {
        farmGenerator = _farmGenerator;
    }

    /**
     * @notice initialize the farming contract. 
     * This is called only once upon farm creation and the FarmGenerator ensures the farm has the correct paramaters
     */
    function init (
        IERC20 _rewardToken, 
        uint256 _amount,
        IERC20 _lpToken, 
        uint256 _blockReward, 
        uint256 _startBlock, 
        uint256 _endBlock, 
        uint256 _bonusEndBlock, 
        uint256 _bonus
        ) external onlyOwner {
        require(msg.sender == address(farmGenerator), 'FORBIDDEN');

        // TransferHelper.safeTransferFrom(address(_rewardToken), msg.sender, address(this), _amount);
        farmInfo.rewardToken = _rewardToken;
        
        farmInfo.startBlock = _startBlock;
        farmInfo.blockReward = _blockReward;
        farmInfo.bonusEndBlock = _bonusEndBlock;
        farmInfo.bonus = _bonus;
        
        uint256 lastRewardBlock = block.number > _startBlock ? block.number : _startBlock;
        farmInfo.lpToken = _lpToken;
        farmInfo.lastRewardBlock = lastRewardBlock;
        farmInfo.accRewardPerShare = 0;
        
        farmInfo.endBlock = _endBlock;
        farmInfo.farmableSupply = _amount;
    }

    /**
     * @notice Gets the reward multiplier over the given _from_block until _to block
     * @param _from_block the start of the period to measure rewards for
     * @param _to the end of the period to measure rewards for
     * @return The weighted multiplier for the given period
     */
    function getMultiplier(uint256 _from_block, uint256 _to) public view returns (uint256) {
        uint256 _from = _from_block >= farmInfo.startBlock ? _from_block : farmInfo.startBlock;
        uint256 to = farmInfo.endBlock > _to ? _to : farmInfo.endBlock;
        if (to <= farmInfo.bonusEndBlock) {
            return to.sub(_from).mul(farmInfo.bonus);
        } else if (_from >= farmInfo.bonusEndBlock) {
            return to.sub(_from);
        } else {
            return farmInfo.bonusEndBlock.sub(_from).mul(farmInfo.bonus).add(
                to.sub(farmInfo.bonusEndBlock)
            );
        }
    }

    /**
     * @notice function to see accumulated balance of reward token for specified user
     * @param _user the user for whom unclaimed tokens will be shown
     * @return total amount of withdrawable reward tokens
     */
    function pendingReward(address _user) external view returns (uint256) {
        UserInfo storage user = userInfo[_user];
        uint256 accRewardPerShare = farmInfo.accRewardPerShare;
        uint256 lpSupply = farmInfo.lpToken.balanceOf(address(this));
        if (block.number > farmInfo.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(farmInfo.lastRewardBlock, block.number);
            uint256 tokenReward = multiplier.mul(farmInfo.blockReward);
            accRewardPerShare = accRewardPerShare.add(tokenReward.mul(1e12).div(lpSupply));
        }
        return user.amount.mul(accRewardPerShare).div(1e12).sub(user.rewardDebt);
    }

    /**
     * @notice updates pool information to be up to date to the current block
     */
    function updatePool() public {
        if (block.number <= farmInfo.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = farmInfo.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            farmInfo.lastRewardBlock = block.number < farmInfo.endBlock ? block.number : farmInfo.endBlock;
            return;
        }
        uint256 multiplier = getMultiplier(farmInfo.lastRewardBlock, block.number);
        uint256 tokenReward = multiplier.mul(farmInfo.blockReward);
        farmInfo.accRewardPerShare = farmInfo.accRewardPerShare.add(tokenReward.mul(1e12).div(lpSupply));
        farmInfo.lastRewardBlock = block.number < farmInfo.endBlock ? block.number : farmInfo.endBlock;
    }

    function deposit(
        uint256 _pid,        
        bytes32 _trustedBlockhash,
        bytes memory _rlpEncodedBlockHeader,
        bytes memory _rlpEncodedReceipt,
        bytes memory _receiptPath,
        bytes memory _receiptWitness,
        uint8 _transferEventIndex,
        bytes32 _receiptsRoot
    ) public {

        require(_receiptsRoot != bytes32(0), "Invalid receipts root");
        require(receipts[_receiptsRoot] == false, "Tx already processed");

        receipts[_receiptsRoot] = true;

        // validations 
        bool proofVerification = EventProof.proveReceiptInclusion(
            _trustedBlockhash,
            _rlpEncodedBlockHeader,
            _rlpEncodedReceipt,
            _receiptPath,
            _receiptWitness
        );

        require(proofVerification == true, "Merkle Proof verification failed");

        // It is an array consisting of below data points :
        //      contract address on which event is fired
        //      Array : 
        //             unique id for event fired --- hash of event signature
        //             from  
        //             to 
        //      value - transferred value
        RLPReader.RLPItem[] memory rlpReceiptList = RLPReader.toList(RLPReader.toRlpItem(_rlpEncodedReceipt));

        // Here we get all the events fired in the receipt.
        RLPReader.RLPItem[] memory rlpEventList =  RLPReader.toList(rlpReceiptList[EVENT_INDEX_IN_RECEIPT]);        

        RLPReader.RLPItem[] memory transferEventList = RLPReader.toList(rlpEventList[_transferEventIndex]);

        RLPReader.RLPItem[] memory transferEventParams = RLPReader.toList(
            transferEventList[TRANSFER_EVENT_PARAMS_INDEX_IN_RECEIPT]
        );

        require(
            address(RLPReader.toUint(transferEventList[0])) == CRYPTION_VALIDATOR_SHARE_PROXY_CONTRACT, 
            "Stake only using Cryption Network validator"
        );

        // Transfer event signature
        require(bytes32(transferEventParams[0].toUint())  == TRANSFER_EVENT_SIG , "Invalid event signature");

        // `to` adddress must be masterchef contract
        require(
            address(RLPReader.toUint(transferEventParams[2]))  == address(this), 
            "Shares must be transferred to masterchef"
        );

        deposit_internal(
            // _pid,
            address(transferEventParams[1].toUint()), // `from` address
            transferEventList[2].toUint() // Value transferred
        );

    }

    
    /**
     * @notice deposit LP token function for msg.sender
     * @param _amount the total deposit amount
     */
    function deposit_internal(address _user, uint256 _amount) internal {
        UserInfo storage user = userInfo[_user];
        updatePool();
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(farmInfo.accRewardPerShare).div(1e12).sub(user.rewardDebt);
            _safeRewardTransfer(_user, pending);
        }
        if (user.amount == 0 && _amount > 0) {
            farmInfo.numFarmers++;
        }
        // farmInfo.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
        user.amount = user.amount.add(_amount);
        user.rewardDebt = user.amount.mul(farmInfo.accRewardPerShare).div(1e12);
        emit Deposit(_user, _amount);
    }

    /**
     * @notice withdraw LP token function for msg.sender
     * @param _amount the total withdrawable amount
     */
    function withdraw(uint256 _amount) public {
        UserInfo storage user = userInfo[msg.sender];
        require(user.amount >= _amount, "INSUFFICIENT");
        updatePool();
        if (user.amount == _amount && _amount > 0) {
            farmInfo.numFarmers--;
        }
        uint256 pending = user.amount.mul(farmInfo.accRewardPerShare).div(1e12).sub(user.rewardDebt);
        _safeRewardTransfer(msg.sender, pending);
        user.amount = user.amount.sub(_amount);
        user.rewardDebt = user.amount.mul(farmInfo.accRewardPerShare).div(1e12);
        farmInfo.lpToken.safeTransfer(address(msg.sender), _amount);
        emit Withdraw(msg.sender, _amount);
    }

    /**
     * @notice emergency functoin to withdraw LP tokens and forego harvest rewards. Important to protect users LP tokens
     */
    function emergencyWithdraw() public {
        UserInfo storage user = userInfo[msg.sender];
        farmInfo.lpToken.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, user.amount);
        if (user.amount > 0) {
            farmInfo.numFarmers--;
        }
        user.amount = 0;
        user.rewardDebt = 0;
    }

    /**
     * @notice Safe reward transfer function, just in case a rounding error causes pool to not have enough reward tokens
     * @param _to the user address to transfer tokens to
     * @param _amount the total amount of tokens to transfer
     */
    function _safeRewardTransfer(address _to, uint256 _amount) internal {
        uint256 rewardBal = farmInfo.rewardToken.balanceOf(address(this));
        if (_amount > rewardBal) {
            farmInfo.rewardToken.transfer(_to, rewardBal);
        } else {
            farmInfo.rewardToken.transfer(_to, _amount);
        }
    }
}
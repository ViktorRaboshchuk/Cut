// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "forge-std/console.sol";

contract Pot is Ownable(msg.sender) {
    error Pot__RewardNotFound();
    error Pot__InsufficientFunds();
    error Pot__StillOpenForClaim();

    address[] private i_players;
    uint256[] private i_rewards;
    address[] private claimants;
    uint256 private immutable i_totalRewards;
    uint256 private immutable i_deployedAt;
    IERC20 private immutable i_token;
    mapping(address => uint256) private playersToRewards;
    uint256 private remainingRewards;
    uint256 private constant managerCutPercent = 10;

    constructor(address[] memory players, uint256[] memory rewards, IERC20 token, uint256 totalRewards) {
        //@audit no parameters validation
        i_players = players;
        i_rewards = rewards;
        i_token = token;
        i_totalRewards = totalRewards;
        remainingRewards = totalRewards;
        i_deployedAt = block.timestamp;

        //@audit why it is commented ?
        // i_token.transfer(address(this), i_totalRewards);

        //@audit possible DOS due to unbounded array length
        for (uint256 i = 0; i < i_players.length; i++) {
            playersToRewards[i_players[i]] = i_rewards[i];
        }
    }

    function claimCut() public {
        address player = msg.sender;
        uint256 reward = playersToRewards[player];
        if (reward <= 0) {
            revert Pot__RewardNotFound();
        }
        playersToRewards[player] = 0;
        remainingRewards -= reward;
        claimants.push(player);
        _transferReward(player, reward);
    }

    function closePot() external onlyOwner {
        if (block.timestamp - i_deployedAt < 90 days) {
            revert Pot__StillOpenForClaim();
        }
        if (remainingRewards > 0) {

            //@audit try calculations for multiple users

            console.log("remainingRewards", remainingRewards);
            //@audit calculations issues - due to solidity divvison rounding to 0, the result will be 0 
            uint256 managerCut = remainingRewards / managerCutPercent;
            console.log("managerCut", managerCut);

            //@audit use safeTransfer insted of transfer
            i_token.transfer(msg.sender, managerCut);
            //@audit possible calculations issues
            //@audit due to managerCut calculated incorectly, users are getting almoust full rewards back
            //@audit test this for multiple users
            uint256 claimantCut = (remainingRewards - managerCut) / i_players.length;
            console.log("claimantCut", claimantCut);
            console.log("remainingRewards - managerCut", remainingRewards - managerCut);
            console.log("i_players.length", i_players.length);
            console.log("claimants.length", claimants.length);

            //@audit possible DOS due to unbounded array length
            //@audit for loop over wrong array. claimants is empty because no users are claimed. 
            //@audit should loop over i_players that did not claimed 
            for (uint256 i = 0; i < claimants.length; i++) {
                _transferReward(claimants[i], claimantCut);
            }
        }
    }

    function _transferReward(address player, uint256 reward) internal {
        //@audit use safeTransfer insted of transfer
        i_token.transfer(player, reward);
    }

    function getToken() public view returns (IERC20) {
        return i_token;
    }

    function checkCut(address player) public view returns (uint256) {
        return playersToRewards[player];
    }

    function getRemainingRewards() public view returns (uint256) {
        return remainingRewards;
    }
}

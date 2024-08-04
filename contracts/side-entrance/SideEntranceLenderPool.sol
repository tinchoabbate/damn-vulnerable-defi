// SPDX-License-Identifier: MIT
//这个存的是ETH，所以我们不能用approve来进行攻击了
//这个使用的是在闪电贷当中去触发deposit()函数来增加mapping，最后提取出来
pragma solidity ^0.8.0;

import "solady/src/utils/SafeTransferLib.sol";

interface IFlashLoanEtherReceiver {
    function execute() external payable;
}

/**
 * @title SideEntranceLenderPool
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract SideEntranceLenderPool {
    mapping(address => uint256) private balances;

    error RepayFailed();

    event Deposit(address indexed who, uint256 amount);
    event Withdraw(address indexed who, uint256 amount);

    function deposit() external payable {
        unchecked {
            balances[msg.sender] += msg.value;
        }
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw() external {
        uint256 amount = balances[msg.sender];
        
        delete balances[msg.sender];
        emit Withdraw(msg.sender, amount);

        SafeTransferLib.safeTransferETH(msg.sender, amount);
    }

    function flashLoan(uint256 amount) external {
        uint256 balanceBefore = address(this).balance;

        IFlashLoanEtherReceiver(msg.sender).execute{value: amount}();

        if (address(this).balance < balanceBefore)
            revert RepayFailed();
    }
}
// 虽然我的想法有点抽象和理想，但是我觉得我们链协的长期规划可以参考一下以太坊
// 1. Frontier（前沿）：链协创立至今，有了部分的知名度
// 2. Homestead（家园）：开始进行搭建知识库，有合适的部门划分以及不同的发展方向，从基础方面有了很好的沉淀
// 3. Metropolis（大都会）：分为两个子阶段
//     <1>Byzantium（拜占庭）：在知识库比较健全的同时开始通过分享知识库以及知名度的方式大量吸引想要进入web3的人以及与其它链协进行深入合作（除了几个比较大的链协大多没有知识库，而且现在也不全）
//     <2>Constantinople（君士坦丁堡）：向校外和社会招新（起码西南地区我们是第一个，很多学校没有链协）
// 4. Serenity（宁静）：这个时候上面可能变化了，在政策允许的情况下发链以及其他defi活动
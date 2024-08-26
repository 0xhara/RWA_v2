// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Escrow is Ownable {
    enum EscrowState { AWAITING_PAYMENT, AWAITING_DELIVERY, COMPLETE, DISPUTE }
    
    struct Transaction {
        address buyer;
        address seller;
        uint256 assetId;
        uint256 amount;
        EscrowState state;
    }

    IERC20 public usdc;
    mapping(uint256 => Transaction) public transactions;
    uint256 public nextTransactionId;

    event PaymentDeposited(uint256 indexed transactionId, address indexed buyer, uint256 amount);
    event PaymentReleased(uint256 indexed transactionId, address indexed seller, uint256 amount);
    event DisputeRaised(uint256 indexed transactionId, address indexed buyer, address indexed seller);

    constructor(address _usdc) {
        usdc = IERC20(_usdc);
    }

    function createTransaction(address seller, uint256 assetId, uint256 amount) external {
        transactions[nextTransactionId] = Transaction({
            buyer: msg.sender,
            seller: seller,
            assetId: assetId,
            amount: amount,
            state: EscrowState.AWAITING_PAYMENT
        });
        nextTransactionId++;
    }

    function depositPayment(uint256 transactionId) external {
        Transaction storage txn = transactions[transactionId];
        require(txn.state == EscrowState.AWAITING_PAYMENT, "Payment already made");
        require(usdc.transferFrom(msg.sender, address(this), txn.amount), "Payment failed");
        txn.state = EscrowState.AWAITING_DELIVERY;
        emit PaymentDeposited(transactionId, txn.buyer, txn.amount);
    }

    function confirmDelivery(uint256 transactionId) external {
        Transaction storage txn = transactions[transactionId];
        require(txn.state == EscrowState.AWAITING_DELIVERY, "Not in correct state");
        require(msg.sender == txn.buyer, "Only buyer can confirm delivery");
        txn.state = EscrowState.COMPLETE;
        usdc.transfer(txn.seller, txn.amount);
        emit PaymentReleased(transactionId, txn.seller, txn.amount);
    }

    function raiseDispute(uint256 transactionId) external {
        Transaction storage txn = transactions[transactionId];
        require(txn.state == EscrowState.AWAITING_DELIVERY, "Not in correct state");
        require(msg.sender == txn.buyer || msg.sender == txn.seller, "Only buyer or seller can raise dispute");
        txn.state = EscrowState.DISPUTE;
        emit DisputeRaised(transactionId, txn.buyer, txn.seller);
    }

    function resolveDispute(uint256 transactionId, bool releaseFundsToSeller) external onlyOwner {
        Transaction storage txn = transactions[transactionId];
        require(txn.state == EscrowState.DISPUTE, "Not in dispute");
        txn.state = EscrowState.COMPLETE;
        if (releaseFundsToSeller) {
            usdc.transfer(txn.seller, txn.amount);
        } else {
            usdc.transfer(txn.buyer, txn.amount);
        }
        emit PaymentReleased(transactionId, releaseFundsToSeller ? txn.seller : txn.buyer, txn.amount);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC777/ERC777.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IERC1363Receiver.sol";

contract CurveToken is ERC777, IERC1363Receiver, Ownable {
    uint256 public tokenPrice;
    uint256 public reserve;
    uint256 public constant INITIAL_TOKEN_PRICE = 1 ether;
    uint256 public constant TOKEN_PRICE_INCREMENT = 1 ether;

    constructor(
        uint256 initialSupply,
        address[] memory defaultOperators
    ) ERC777("MyToken", "MTK", defaultOperators) {
        _mint(msg.sender, initialSupply, "", "");
        tokenPrice = INITIAL_TOKEN_PRICE;
    }

    function buyTokens(uint256 amount) public payable {
        require(amount > 0, "Amount must be greater than zero");

        uint256 totalPrice = calculateTotalPrice(amount);
        require(msg.value >= totalPrice, "Insufficient payment");

        reserve += msg.value;
        _mint(msg.sender, amount, "", "");
        tokenPrice = calculateTokenPrice(totalPrice);
    }

    function sellTokens(uint256 amount) public {
        require(amount > 0, "Amount must be greater than zero");

        uint256 payment = calculatePayment(amount);
        require(payment <= reserve, "Insufficient reserve");

        reserve -= payment;
        _burn(msg.sender, amount, "", "");
        payable(msg.sender).transfer(payment);
        tokenPrice = calculateTokenPrice(payment);
    }

    function calculateTotalPrice(uint256 amount) private view returns (uint256) {
        return ((2 * amount * INITIAL_TOKEN_PRICE) + ((amount - 1) * TOKEN_PRICE_INCREMENT)) / 2;
    }

    function calculatePayment(uint256 amount) private view returns (uint256) {
        return ((2 * amount * tokenPrice) - ((amount - 1) * TOKEN_PRICE_INCREMENT)) / 2;
    }

    function calculateTokenPrice(uint256 totalPrice) private view returns (uint256) {
        return ((2 * totalPrice) - ((totalSupply() - 1) * TOKEN_PRICE_INCREMENT)) / (2 * totalSupply());
    }

    function onTransferReceived(
        address /* operator */,
        address from,
        uint256 amount,
        bytes memory data
    ) public virtual override returns (bytes4) {
        require(msg.sender == address(this), "Invalid token");
        require(data.length == 0, "Data not supported");

        uint256 payment = calculatePayment(amount);
        reserve += payment;
        _mint(from, amount, "", "");
        return this.onTransferReceived.selector;
    }

    function onTokensReceived(
        address operator,
        address from,
        uint256 amount,
        bytes memory data,
        bytes memory /*operatorData*/
    ) public returns (bytes4) {
        require(msg.sender == address(this), "Invalid token");
        require(data.length == 0, "Data not supported");

        uint256 payment = calculatePayment(amount);
        reserve -= payment;
        _burn(operator, amount, "", "");
        payable(from).transfer(payment);
        return this.onTokensReceived.selector;
    }

    function withdraw(uint256 amount) public onlyOwner {
        require(amount <= reserve, "Insufficient reserve");
        reserve -= amount;
        payable(msg.sender).transfer(amount);
    }
}

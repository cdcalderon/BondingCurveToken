// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC777/ERC777.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IERC1363Receiver.sol";

contract CurveToken is ERC777, IERC1363Receiver, Ownable {
    uint256 public tokenPrice;
    uint256 public reserve;
    uint256 public constant INITIAL_TOKEN_PRICE = 1 ether;
    uint256 public constant TOKEN_PRICE_INCREMENT = 1 ether;

    /**
     * @dev Contract constructor.
     * @param initialSupply The initial supply of tokens.
     * @param defaultOperators An array of addresses to set as default operators for the token.
     */
    constructor(
        uint256 initialSupply,
        address[] memory defaultOperators
    ) ERC777("MyToken", "MTK", defaultOperators) {
        _mint(msg.sender, initialSupply, "", "");
        tokenPrice = INITIAL_TOKEN_PRICE;
    }

    /**
     * @dev Buy tokens by sending ether to the contract.
     * @param amount The amount of tokens to buy.
     */
    function buyTokens(uint256 amount) public payable {
        require(amount > 0, "Amount must be greater than zero");

        uint256 totalPrice = calculateTotalPrice(amount);
        require(msg.value >= totalPrice, "Insufficient payment");

        reserve += msg.value;
        uint256 actualAmount = calculateAmount(msg.value);
        _mint(msg.sender, actualAmount, "", "");
        tokenPrice = calculateTokenPrice(totalPrice);
    }

    /**
     * @dev Sell tokens and receive ether from the contract.
     * @param amount The amount of tokens to sell.
     */
    function sellTokens(uint256 amount) public {
        require(amount > 0, "Amount must be greater than zero");

        uint256 payment = calculatePayment(amount);
        require(payment <= reserve, "Insufficient reserve");

        uint256 actualAmount = (amount * INITIAL_TOKEN_PRICE) / tokenPrice;
        reserve -= payment;
        _burn(msg.sender, actualAmount, "", "");
        payable(msg.sender).transfer(payment);
        tokenPrice = calculateTokenPrice(payment);
    }

    /**
     * @dev Calculates the amount of tokens that can be bought with a given payment.
     * @param payment The payment amount in wei.
     * @return The amount of tokens that can be bought.
     */
    function calculateAmount(uint256 payment) private view returns (uint256) {
        uint256 amount = 0;
        uint256 remainingPayment = payment;
        while (remainingPayment >= calculateTotalPrice(amount + 1)) {
            amount += 1;
            remainingPayment -= calculateTotalPrice(amount);
        }
        return amount;
    }

    /**
     * @dev Calculate the total price to buy a given amount of tokens.
     * @param amount The amount of tokens to buy.
     * @return The total price to buy the tokens in wei.
     */
    function calculateTotalPrice(
        uint256 amount
    ) private view returns (uint256) {
        return
            ((2 * amount * INITIAL_TOKEN_PRICE) +
                ((amount - 1) * TOKEN_PRICE_INCREMENT)) / 2;
    }

    /**
     * @dev Calculate the payment a user will receive when selling a given amount of tokens.
     * @param amount The amount of tokens to sell.
     * @return The payment in wei.
     */
    function calculatePayment(uint256 amount) private view returns (uint256) {
        return
            ((2 * amount * tokenPrice) -
                ((amount - 1) * TOKEN_PRICE_INCREMENT)) / 2;
    }

    /**
     * @dev Calculate the current token price based on the reserve and total supply.
     * @param totalPrice The total price paid to buy tokens.
     * @return The current token price in wei.
     */
    function calculateTokenPrice(
        uint256 totalPrice
    ) private view returns (uint256) {
        return
            ((2 * totalPrice) - ((totalSupply() - 1) * TOKEN_PRICE_INCREMENT)) /
            (2 * totalSupply());
    }

    /**
     * @dev Hook that is called when a transfer of ERC777 token is received.
     * @param from The address which previously owned the token.
     * @param amount The amount of tokens that were transferred.
     * @param data Additional data with no specified format. Should contain the minimum amount required.
     * @return `bytes4(keccak256("onTransferReceived(address,address,uint256,bytes)"))`.
     * This function MUST return this exact value (unless overridden).
     * This function MUST NOT have external interactions.
     */
    function onTransferReceived(
        address /* operator */,
        address from,
        uint256 amount,
        bytes memory data
    ) public virtual override returns (bytes4) {
        require(msg.sender == address(this), "Invalid token");
        uint256 minimumAmount = abi.decode(data, (uint256));
        require(amount >= minimumAmount, "Slippage error: insufficient amount");

        uint256 payment = calculatePayment(amount);
        reserve += payment;
        _mint(from, amount, "", "");
        return this.onTransferReceived.selector;
    }

    /**
     * @dev ERC1363 callback function. Called by the token contract when tokens are received.
     * @param operator The address that triggered the operation.
     * @param from The address which previously owned the token.
     * @param amount The number of tokens received.
     * @param operatorData Additional data with no specified format, as provided by the operator.
     * @return bytes4 `bytes4(keccak256("onTokensReceived(address,address,uint256,bytes,bytes)"))`
     * unless throwing.
     */
    function onTokensReceived(
        address operator,
        address from,
        uint256 amount,
        bytes memory data,
        bytes memory operatorData
    ) public returns (bytes4) {
        require(msg.sender == address(this), "Invalid token");
        require(data.length == 0, "Data not supported");

        uint256 minimumOut = abi.decode(operatorData, (uint256));
        require(amount >= minimumOut, "Insufficient amount received");

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

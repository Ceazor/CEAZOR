// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "contracts/interfaces/ITurnstile.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Mintable.sol";

// TO:DO these imports below need to be completed
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

import {IPair} from "./interfaces/IPair.sol";
import {ITurnstile} from "./ITurnstile.sol";
 

/// @title Options Token
/// @notice Options token representing the right to purchase the underlying token
/// at TWAP reduced rate. Similar to call options but with a variable strike
/// price that's always at a certain discount to the market price.
/// @dev Assumes the underlying token and the payment token both use 18 decimals.

/// !!!!!
/// TO:DO figure out how BLOTR which is not mintable will be held and dispersed to replace line 224


contract OptionsToken is ERC20, Ownable, IERC20Mintable {
    /// -----------------------------------------------------------------------
    /// Library usage
    /// -----------------------------------------------------------------------

    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    error OptionsToken__PastDeadline();
    error OptionsToken__NotTokenAdmin();
    error OptionsToken__SlippageTooHigh();

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event Exercise(address indexed sender, address indexed recipient, uint256 amount, uint256 paymentAmount);
    event SetPair(IPair indexed newPair);
    event SetTreasury(address indexed newTreasury);
    event SetDiscount(uint256 indexed discount);

    /// -----------------------------------------------------------------------
    /// Immutable parameters
    /// -----------------------------------------------------------------------

    /// @notice The contract that has the right to mint options tokens
    address public immutable tokenAdmin;

    /// @notice The token paid by the options token holder during redemption
    ERC20 public immutable paymentToken;

    /// @notice The underlying token purchased during redemption
    IERC20Mintable public immutable underlyingToken;

    /// -----------------------------------------------------------------------
    /// Storage variables
    /// -----------------------------------------------------------------------

    /// @notice The pair contract that provides the current TWAP price to purchase
    /// the underlying token while exercising options (the strike price)
    IPair public pair;

    /// @notice The treasury address which receives tokens paid during redemption
    address public treasury;

    /// @notice the discount given during exercising. 30 = user pays 30%
    uint256 public discount;

    ITurnstile turnstile;


    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(
        string memory name_,
        string memory symbol_,
        address owner_,
        address tokenAdmin_,
        ERC20 paymentToken_,
        IERC20Mintable underlyingToken_,
        IPair pair_,
        address treasury_,
        uint256 discount_,
        address turnstile_,
        uint256 _csrNftId
    ) ERC20(name_, symbol_, 18) Owned(owner_) {
        tokenAdmin = tokenAdmin_;
        paymentToken = paymentToken_;
        underlyingToken = underlyingToken_;
        pair = pair_;
        treasury = treasury_;
        discount = discount_;
        turnstile = ITurnstile(_turnstile); 
        turnstile.assign(_csrNftId);

        emit SetPair(pair_);
        emit SetTreasury(treasury_);
    }

    /// -----------------------------------------------------------------------
    /// External functions
    /// -----------------------------------------------------------------------

    /// @notice Called by the token admin to mint options tokens
    /// @param to The address that will receive the minted options tokens
    /// @param amount The amount of options tokens that will be minted
    function mint(address to, uint256 amount) external virtual override {
        /// -----------------------------------------------------------------------
        /// Verification
        /// -----------------------------------------------------------------------

        if (msg.sender != tokenAdmin) revert OptionsToken__NotTokenAdmin();

        /// -----------------------------------------------------------------------
        /// State updates
        /// -----------------------------------------------------------------------

        // skip if amount is zero
        if (amount == 0) return;

        // mint options tokens
        _mint(to, amount);
    }

    /// @notice Exercises options tokens to purchase the underlying tokens.
    /// @dev The options tokens are not burnt but sent to address(0) to avoid messing up the
    /// inflation schedule.
    /// The oracle may revert if it cannot give a secure result.
    /// @param amount The amount of options tokens to exercise
    /// @param maxPaymentAmount The maximum acceptable amount to pay. Used for slippage protection.
    /// @param recipient The recipient of the purchased underlying tokens
    /// @return paymentAmount The amount paid to the treasury to purchase the underlying tokens
    function exercise(uint256 amount, uint256 maxPaymentAmount, address recipient)
        external
        virtual
        returns (uint256 paymentAmount)
    {
        return _exercise(amount, maxPaymentAmount, recipient);
    }

    /// @notice Exercises options tokens to purchase the underlying tokens.
    /// @dev The options tokens are not burnt but sent to address(0) to avoid messing up the
    /// inflation schedule.
    /// The oracle may revert if it cannot give a secure result.
    /// @param amount The amount of options tokens to exercise
    /// @param maxPaymentAmount The maximum acceptable amount to pay. Used for slippage protection.
    /// @param recipient The recipient of the purchased underlying tokens
    /// @param deadline The Unix timestamp (in seconds) after which the call will revert
    /// @return paymentAmount The amount paid to the treasury to purchase the underlying tokens
    function exercise(uint256 amount, uint256 maxPaymentAmount, address recipient, uint256 deadline)
        external
        virtual
        returns (uint256 paymentAmount)
    {
        if (block.timestamp > deadline) revert OptionsToken__PastDeadline();
        return _exercise(amount, maxPaymentAmount, recipient);
    }

    /// -----------------------------------------------------------------------
    /// Owner functions
    /// -----------------------------------------------------------------------

    /// @notice Sets the pair contract. Only callable by the owner.
    /// @param pair_ The new pair contract
    function setPair(IOracle pair_) external onlyOwner {
        require(pair_ != pair, 'this is already the pair');
        pair = pair_;
        emit SetPair(pair_);
    }

    /// @notice Sets the treasury address. Only callable by the owner.
    /// @param treasury_ The new treasury address
    function setTreasury(address treasury_) external onlyOwner {
        require(treasury_ != address(0));
        treasury = treasury_;
        emit SetTreasury(treasury_);
    }
    /// @notice Sets the discount amount. Only callable by the owner.
    /// @param discount_ The new discount amount.
    function setDiscount(address discount_) external onlyOwner {
        require(discount_ <= 100, 'cant ask user to pay more than full price');
        require(discount_ > 0, 'cant ask give user for free');
        discount = discount_;
        emit SetDiscount(discount_);
    }

    /// -----------------------------------------------------------------------
    /// Internal functions
    /// -----------------------------------------------------------------------

    function _exercise(uint256 amount, uint256 maxPaymentAmount, address recipient)
        internal
        virtual
        returns (uint256 paymentAmount)
    {
        // skip if amount is zero
        if (amount == 0) return 0;

        // transfer options tokens from msg.sender to address(0)
        // we transfer instead of burn because TokenAdmin cares about totalSupply
        // which we don't want to change in order to follow the emission schedule
        transfer(address(0), amount);

        // transfer payment tokens from msg.sender to the treasury
            
        //calcs the price, discount is how much they pay. 
        uint [] memory amtsOut = IPair(pair).prices(underlyingToken, amount, 4);
            uint amtsOut0 = amtsOut[0]; 
            uint amtsOut1 = amtsOut[1] ;
            uint amtsOut2 = amtsOut[2] ;
            uint amtsOut3 = amtsOut[3] ;
        uint256 price = ((amtsOut0 + amtsOut1 + amtsOut2 + amtsOut3) / 4) * discount / 100 ;  


        paymentAmount = amount.mulWadUp(price);
        if (paymentAmount > maxPaymentAmount) revert OptionsToken__SlippageTooHigh();
        paymentToken.safeTransferFrom(msg.sender, treasury, paymentAmount);

        // mint underlying tokens to recipient
        underlyingToken.mint(recipient, amount);

        emit Exercise(msg.sender, recipient, amount, paymentAmount);
    }
}

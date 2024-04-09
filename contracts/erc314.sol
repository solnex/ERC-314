/**
 *Submitted for verification at Etherscan.io on 2024-04-09
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ERC314
 * @dev Implementation of the ERC314 interface.
 * ERC314 is a derivative of ERC20 which aims to integrate a liquidity pool on the token in order to enable native swaps, notably to reduce gas consumption.
 */

// Events interface for ERC314
interface IEERC314 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event AddLiquidity(uint32 _timeTillUnlockLiquidity, uint256 value);
    event RemoveLiquidity(uint256 value);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
}

interface IFactory {
    function getOwner() external view returns (address);
}

abstract contract ERC314 is IEERC314 {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;
    uint256 private _hardTop = 1000 ether;
    uint256 public maxWallet;
    uint256 public tradingTime;
    string private _name;
    string private _symbol;
    address public owner;
    address public feeCollector;
    address public WETH = 0x4200000000000000000000000000000000000006;
    address public token1 = address(this);
    address public token0 = WETH;
    address public factory;
    bool public tradingEnable;
    bool public maxWalletEnable;
    uint256 public fee; //trading fee

    mapping(address => uint32) public lastTransaction;
    uint256 public accruedFeeAmount;

    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable: caller is not the owner");
        _;
    }


    modifier onlyFeeCollector() {
        require(msg.sender == feeCollector, "You are not the fee collector");
        _;
    }

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 totalSupply_,
        uint256 _fee,
        address _factory,
        uint256 _tradingTime
    ) {
        _name = name_;
        _symbol = symbol_;
        _totalSupply = totalSupply_;
        maxWallet = totalSupply_ / 20;
        owner = msg.sender;
        maxWalletEnable = true;
        feeCollector = msg.sender;
        fee = _fee;
        factory = _factory;
        tradingTime = _tradingTime;
    }

    function name() public view virtual returns (string memory) {
        return _name;
    }

    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 value) public virtual returns (bool) {
     
        _transfer(msg.sender, to, value);
        
        return true;
    }

    function allowance(address _owner, address spender) public view virtual returns (uint256) {
        return _allowances[_owner][spender];
    }

    function approve(address spender, uint256 value) public virtual returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) public virtual returns (bool) {
        require(_allowances[from][msg.sender] >= value, "ERC314: transfer amount exceeds allowance");
        _transfer(from, to, value);
        _approve(from, msg.sender, _allowances[from][msg.sender] - value);
        return true;
    }

    function _approve(address _owner, address spender, uint256 value) internal virtual {
        require(_owner != address(0), "ERC314: approve from the zero address");
        require(spender != address(0), "ERC314: approve to the zero address");

        _allowances[_owner][spender] = value;
        emit Approval(_owner, spender, value);
    }

    function _transfer(
        address from,
        address to,
        uint256 value
    ) internal virtual {

        require(
            _balances[from] >= value,
            "ERC20: transfer amount exceeds balance"
        );

        unchecked {
            _balances[from] -= value;
        }

        if (to == address(0)) {
            unchecked {
                _totalSupply -= value;
            }
        } else {
            unchecked {
                _balances[to] += value;
            }
        }

        emit Transfer(from, to, value);
    }

    /**
     * @dev Returns the amount of ETH and tokens in the contract, used for trading.
     */
    function getReserves() public view returns (uint256, uint256) {
        return (
            (address(this).balance - accruedFeeAmount),
            _balances[address(this)]
        );
      
    }
     
     function _mint(address to,uint256 amount) internal {
          unchecked {
                _balances[to] += amount;
                _balances[address(this)] += amount;
            }
          emit Transfer(address(0), to, amount);
     }

    /**
     * @dev Enables or disables trading.
     * @param _tradingEnable: true to enable trading, false to disable trading.
     * onlyOwner modifier
     */
    function enableTrading(bool _tradingEnable) external onlyOwner {
        tradingEnable = _tradingEnable;
    }

    /**
     * @dev Enables or disables the max wallet.
     * @param _maxWalletEnable: true to enable max wallet, false to disable max wallet.
     * onlyOwner modifier
     */
    function enableMaxWallet(bool _maxWalletEnable) external onlyOwner {
        maxWalletEnable = _maxWalletEnable;
    }

    /**
     * @dev Modify trading fees
     * @param _fee: trading fee amount
     * onlyOwner modifier
     */

    function setTradingFee(uint256 _fee) external onlyOwner {
        require(_fee <= 500, "max 5% fee");
        fee = _fee;
    }


    /**
     * @dev Sets the max wallet.
     * @param _maxWallet_: the new max wallet.
     * onlyOwner modifier
     */
    function setMaxWallet(uint256 _maxWallet_) external onlyOwner {
        maxWallet = _maxWallet_;
    }

    /**
     *
     * @dev Sets the new fee collector
     * @param _newFeeCollector the new fee collector
     * onlyOwner modifier
     */
    function setFeeCollector(address _newFeeCollector) external onlyOwner {
        feeCollector = _newFeeCollector;
    }

    /**
     * @dev Transfers the ownership of the contract to zero address
     * onlyOwner modifier
     */
    function renounceOwnership() external onlyOwner {
        owner = address(0);
    }


    /**
     * @dev Estimates the amount of tokens or ETH to receive when buying or selling.
     * @param value: the amount of ETH or tokens to swap.
     * @param _buyBool: true if buying, false if selling.
     */
    function getAmountOut(
        uint256 value,
        bool _buyBool
    ) public view returns (uint256) {
        (uint256 reserveETH, uint256 reserveToken) = getReserves();

        if (_buyBool) {
            uint256 valueAfterFee = (value * (10000 - fee)) / 10000;
            return ((valueAfterFee * reserveToken)) / (reserveETH + valueAfterFee);
        } else {
            uint256 ethValue = ((value * reserveETH)) / (reserveToken + value);
            ethValue = (ethValue * (10000 - fee)) / 10000;
            return ethValue;
        }
    }

    /**
     * @dev Buys tokens with ETH.
     * internal function
     */
    function buy(uint256 amountOutMin) public payable {
        require(block.timestamp >= tradingTime,"trading is not open");
        uint256 feeAmount = (msg.value * fee) / 10000;

        uint256 ETHafterFee;
        unchecked {
            ETHafterFee = msg.value - feeAmount;
        }

        unchecked {
            accruedFeeAmount += feeAmount;
        }
        (uint256 reserveETH, uint256 reserveToken) = getReserves();

        uint256 tokenAmount = (ETHafterFee * reserveToken) / reserveETH;
        require(tokenAmount > 0, "Bought amount too low");

        if (maxWalletEnable) {
            require(
                tokenAmount + _balances[msg.sender] <= maxWallet,
                "Max wallet exceeded"
            );
        }

        require(tokenAmount >= amountOutMin, "slippage reached");

        _transfer(address(this), msg.sender, tokenAmount);

        emit Swap(msg.sender, msg.value, 0, 0, tokenAmount,msg.sender);
    }



    // Add a new variable to hold the factory address and a function to set it (only once)

    function setFactoryAddress(address _factory) external {
        require(factory == address(0), "Factory address already set");
        factory = _factory;
    }

    // Modify the claimFees function to distribute fees accordingly
    function claimFees() external  onlyFeeCollector {
        uint256 totalAccruedAmount = accruedFeeAmount;
        if (totalAccruedAmount > address(this).balance) {
            totalAccruedAmount = address(this).balance;
        }

        uint256 factoryShare = (totalAccruedAmount * 10) / 100; // 10% to factory owner
        uint256 ownerShare = totalAccruedAmount - factoryShare;

        accruedFeeAmount = 0;

        if(factoryShare > 0) {
            (bool successFactory, ) = payable(IFactory(factory).getOwner()).call{value: factoryShare}("");
            require(successFactory, "Transfer of factory share failed");
        }

        (bool successOwner, ) = payable(msg.sender).call{value: ownerShare}("");
        require(successOwner, "Transfer of owner share failed");
    }


    /**
     * @dev Sells tokens for ETH.
     * internal function
     */
    function sell(uint256 sellAmount, uint256 amountOutMin) public {
       require( block.timestamp >= tradingTime,"trading is not open");
        (uint256 reserveETH, uint256 reserveToken) = getReserves();

        uint256 ethAmount = (sellAmount * reserveETH) /
            (reserveToken + sellAmount);

        require(reserveETH >= ethAmount, "Insufficient ETH in reserves");

        uint256 feeAmount = (ethAmount * fee) / 10000;

        unchecked {
            ethAmount -= feeAmount;
        }
        require(ethAmount > 0, "Sell amount too low");
        require(ethAmount >= amountOutMin, "slippage reached");

        unchecked {
            accruedFeeAmount += feeAmount;
        }

        _transfer(msg.sender, address(this), sellAmount);

        (bool success, ) = payable(msg.sender).call{value: ethAmount}("");
        if (!success) {
            revert("Could not sell");
        }

        emit Swap(msg.sender, 0, sellAmount, ethAmount, 0, msg.sender);
    }

    function getTokenFromEth(uint256 ethAmount) private view returns(uint256){
           return ethAmount * _totalSupply * 50 / 100 /_hardTop;
    }
    
    receive()external payable {
        if(block.timestamp < tradingTime){
            _mint(msg.sender, getTokenFromEth(msg.value));
        }
        else buy(0);
    }
}

contract EVToken is ERC314 {
    constructor(string memory name_,
        string memory symbol_,
        uint256 totalSupply_,
        uint256 _fee,
        address _factory, 
        uint256 _tradingTime) ERC314(name_, symbol_, totalSupply_, _fee, _factory, _tradingTime) {}
}

contract ERC314Factory {
    address[] public allTokens;
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    event TokenCreated(address tokenAddress);

    function createERC314(
        string memory name,
        string memory symbol,
        uint256 totalSupply,
        uint256 fee,
        uint256 tradingTime
    ) public {
        EVToken newToken = new EVToken(name, symbol, totalSupply, fee, owner, tradingTime);
        allTokens.push(address(newToken));
        emit TokenCreated(address(newToken));
    }

    // Add function to retrieve factory owner for fee distribution
    function getOwner() external view returns (address) {
        return owner;
    }

    // Ensure onlyOwner modifier is applied to functions that should be restricted
}
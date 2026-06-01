pragma solidity 0.7.0;

import "./IERC20.sol";
import "./IMintableToken.sol";
import "./IDividends.sol";
import "./SafeMath.sol";

contract Token is IERC20, IMintableToken, IDividends {
  // ------------------------------------------ //
  // ----- BEGIN: DO NOT EDIT THIS SECTION ---- //
  // ------------------------------------------ //
  using SafeMath for uint256;
  uint256 public totalSupply;
  uint256 public decimals = 18;
  string public name = "Test token";
  string public symbol = "TEST";
  mapping (address => uint256) public balanceOf;
  // ------------------------------------------ //
  // ----- END: DO NOT EDIT THIS SECTION ------ //
  // ------------------------------------------ //

  address[] private _holders;
  mapping(address => uint256) private _holderIndex; // 1-based index, 0 = not a holder
  mapping(address => mapping(address => uint256)) private _allowances;
  mapping(address => uint256) private _dividends;

  function _addHolder(address addr) private {
    if (_holderIndex[addr] == 0) {
      _holders.push(addr);
      _holderIndex[addr] = _holders.length;
    }
  }

  function _removeHolder(address addr) private {
    uint256 idx = _holderIndex[addr];
    if (idx == 0) return;
    uint256 last = _holders.length;
    if (idx != last) {
      address lastAddr = _holders[last - 1];
      _holders[idx - 1] = lastAddr;
      _holderIndex[lastAddr] = idx;
    }
    _holders.pop();
    _holderIndex[addr] = 0;
  }

  // IERC20

  function allowance(address owner, address spender) external view override returns (uint256) {
    return _allowances[owner][spender];
  }

  function transfer(address to, uint256 value) external override returns (bool) {
    require(balanceOf[msg.sender] >= value, "Insufficient balance");
    if (value > 0) {
      balanceOf[msg.sender] = balanceOf[msg.sender].sub(value);
      balanceOf[to] = balanceOf[to].add(value);
      if (balanceOf[msg.sender] == 0) {
        _removeHolder(msg.sender);
      }
      _addHolder(to);
    }
    return true;
  }

  function approve(address spender, uint256 value) external override returns (bool) {
    _allowances[msg.sender][spender] = value;
    return true;
  }

  function transferFrom(address from, address to, uint256 value) external override returns (bool) {
    require(balanceOf[from] >= value, "Insufficient balance");
    require(_allowances[from][msg.sender] >= value, "Insufficient allowance");
    _allowances[from][msg.sender] = _allowances[from][msg.sender].sub(value);
    if (value > 0) {
      balanceOf[from] = balanceOf[from].sub(value);
      balanceOf[to] = balanceOf[to].add(value);
      if (balanceOf[from] == 0) {
        _removeHolder(from);
      }
      _addHolder(to);
    }
    return true;
  }

  // IMintableToken

  function mint() external payable override {
    require(msg.value > 0, "No ETH sent");
    balanceOf[msg.sender] = balanceOf[msg.sender].add(msg.value);
    totalSupply = totalSupply.add(msg.value);
    _addHolder(msg.sender);
  }

  function burn(address payable dest) external override {
    uint256 amount = balanceOf[msg.sender];
    balanceOf[msg.sender] = 0;
    totalSupply = totalSupply.sub(amount);
    _removeHolder(msg.sender);
    dest.transfer(amount);
  }

  // IDividends

  function getNumTokenHolders() external view override returns (uint256) {
    return _holders.length;
  }

  function getTokenHolder(uint256 index) external view override returns (address) {
    if (index == 0 || index > _holders.length) {
      return address(0);
    }
    return _holders[index - 1];
  }

  function recordDividend() external payable override {
    require(msg.value > 0, "No ETH sent");
    uint256 supply = totalSupply;
    for (uint256 i = 0; i < _holders.length; i++) {
      address holder = _holders[i];
      _dividends[holder] = _dividends[holder].add(
        msg.value.mul(balanceOf[holder]).div(supply)
      );
    }
  }

  function getWithdrawableDividend(address payee) external view override returns (uint256) {
    return _dividends[payee];
  }

  function withdrawDividend(address payable dest) external override {
    uint256 amount = _dividends[msg.sender];
    _dividends[msg.sender] = 0;
    dest.transfer(amount);
  }
}

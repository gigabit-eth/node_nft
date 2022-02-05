// SPDX-License-Identifier: MIT

// Lepton2.sol -- Part of the Charged Particles Protocol
// Copyright (c) 2021 Firma Lux, Inc. <https://charged.fi>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

pragma solidity ^0.8.0;

import "./lib/ERC721Basic.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

import "./interfaces/INode.sol";
import "./lib/BlackholePrevention.sol";


contract CuboNodes is INode, ERC721Basic, Ownable, ReentrancyGuard, BlackholePrevention {
  using SafeMath for uint256;
  using Address for address payable;

  Classification[] internal _nodeTypes;

  uint256 internal _typeIndex;
  uint256 internal _maxSupply;
  uint256 internal _maxMintPerTx;
  uint256 internal _migratedCount;

  bool internal _paused;
  bool internal _migrationComplete;


  /***********************************|
  |          Initialization           |
  |__________________________________*/

  constructor() public ERC721("Cubo Protocol Nodes", "CuboNodes") {
    _paused = true;
  }


  /***********************************|
  |              Public               |
  |__________________________________*/

  function mintNode() external payable override nonReentrant whenNotPaused returns (uint256 newTokenId) {
    newTokenId = _mintNode(msg.sender);
  }

  function batchMintNode(uint256 count) external payable override nonReentrant whenNotPaused {
    _batchMintNode(msg.sender, count);
  }

  function totalSupply() public view returns (uint256) {
    return _tokenCount;
  }

  function maxSupply() external view returns (uint256) {
    return _maxSupply;
  }

  function getNextType() external view override returns (uint256) {
    if (_typeIndex >= _nodeTypes.length) { return 0; }
    return _typeIndex;
  }

  function getNextPrice() external view override returns (uint256) {
    if (_typeIndex >= _nodeTypes.length) { return 0; }
    return _nodeTypes[_typeIndex].price;
  }

  function getEmission(uint256 tokenId) external view override returns (uint256) {
    require(_exists(tokenId), "CUBO: Token Emission");
    return _getNode(tokenId).emission;
  }

  function getBonus(uint256 tokenId) external view override returns (uint256) {
    require(_exists(tokenId), "LPT:E-405");
    return _getNode(tokenId).bonus;
  }

  function tokenURI(uint256 tokenId) public view override returns (string memory) {
    require(_exists(tokenId), "LPT:E-405");
    return _getNode(tokenId).tokenUri;
  }

  /***********************************|
  |          Only Admin/DAO           |
  |__________________________________*/

  function addNodeType(
    string calldata tokenUri,
    uint256 price,
    uint32 supply,
    uint32 emission,
    uint32 bonus
  )
    external
    onlyOwner
  {
    _maxSupply = _maxSupply.add(uint256(supply));

    Classification memory node = Classification({
      tokenUri: tokenUri,
      price: price,
      supply: supply,
      emission: emission,
      bonus: bonus,
      _upperBounds: uint128(_maxSupply)
    });
    _nodeTypes.push(node);

    emit NodeTypeAdded(tokenUri, price, supply, emission, bonus, _maxSupply);
  }

  function updateNodeType(
    uint256 nodeIndex,
    string calldata tokenUri,
    uint256 price,
    uint32 supply,
    uint32 emission,
    uint32 bonus
  )
    external
    onlyOwner
  {
    _nodeTypes[nodeIndex].tokenUri = tokenUri;
    _nodeTypes[nodeIndex].price = price;
    _nodeTypes[nodeIndex].supply = supply;
    _nodeTypes[nodeIndex].emission = emission;
    _nodeTypes[nodeIndex].bonus = bonus;

    emit NodeTypeUpdated(nodeIndex, tokenUri, price, supply, emission, bonus, _maxSupply);
  }

  function setMaxMintPerTx(uint256 maxAmount) external onlyOwner {
    _maxMintPerTx = maxAmount;
    emit MaxMintPerTxSet(maxAmount);
  }

  function setPausedState(bool state) external onlyOwner whenMigrated {
    _paused = state;
    emit PausedStateSet(state);
  }


  /***********************************|
  |          Only Admin/DAO           |
  |      (blackhole prevention)       |
  |__________________________________*/

  function withdrawEther(address payable receiver, uint256 amount) external onlyOwner {
    _withdrawEther(receiver, amount);
  }

  function withdrawErc20(address payable receiver, address tokenAddress, uint256 amount) external onlyOwner {
    _withdrawERC20(receiver, tokenAddress, amount);
  }

  function withdrawERC721(address payable receiver, address tokenAddress, uint256 tokenId) external onlyOwner {
    _withdrawERC721(receiver, tokenAddress, tokenId);
  }

  function migrateAccounts(address oldNodeContract, uint256 count) external onlyOwner whenNotMigrated {
    uint256 oldSupply = IERC721Enumerable(oldNodeContract).totalSupply();
    if (oldSupply > 0) {
      require(oldSupply > _migratedCount, "NPT:E-004");

      uint256 endTokenId = _migratedCount.add(count);
      if (endTokenId > oldSupply) {
        count = count.sub(endTokenId.sub(oldSupply));
      }

      for (uint256 i = 1; i <= count; i++) {
        uint256 tokenId = _migratedCount.add(i);
        address tokenOwner = IERC721(oldNodeContract).ownerOf(tokenId);
        _mint(tokenOwner);
      }
      _migratedCount = _tokenCount;
    }

    if (oldSupply == _migratedCount) {
      _finalizeMigration();
    }
  }

  /***********************************|
  |         Private Functions         |
  |__________________________________*/

  function _getNode(uint256 tokenId) internal view returns (Classification memory) {
    uint256 types = _nodeTypes.length;
    for (uint256 i = 0; i < types; i++) {
      Classification memory node = _nodeTypes[i];
      if (tokenId <= node._upperBounds) {
        return node;
      }
    }
  }

  function _mintNode(address receiver) internal returns (uint256 newTokenId) {
    require(_typeIndex < _nodeTypes.length, "LPT:E-001");

    Classification memory node = _nodeTypes[_typeIndex];
    require(msg.value >= node.price, "LPT:E-414");

    newTokenId = _safeMint(receiver, "");

    // Determine Next Type
    if (newTokenId == node._upperBounds) {
      _typeIndex = _typeIndex.add(1);
    }

    _refundOverpayment(node.price);
  }

  function _batchMintNode(address receiver, uint256 count) internal {
    require(_typeIndex < _nodeTypes.length, "LPT: E-001");
    require(_maxMintPerTx == 0 || count <= _maxMintPerTx, "LPT:E-429");

    Classification memory node = _nodeTypes[_typeIndex];

    uint256 endTokenId = _tokenCount.add(count);
    if (endTokenId > node._upperBounds) {
      count = count.sub(endTokenId.sub(node._upperBounds));
    }

    uint256 salePrice = node.price.mul(count);
    require(msg.value >= salePrice, "LPT:E-414");

    _safeMintBatch(receiver, count, "");

    // Determine Next Type
    if (endTokenId >= node._upperBounds) {
      _typeIndex = _typeIndex.add(1);
    }

    _refundOverpayment(salePrice);
  }

  function _refundOverpayment(uint256 threshold) internal {
    uint256 overage = msg.value.sub(threshold);
    if (overage > 0) {
      payable(_msgSender()).sendValue(overage);
    }
  }

  function _finalizeMigration() internal {
    // Determine Next Type
    _typeIndex = 0;
    for (uint256 i = 0; i < _nodeTypes.length; i++) {
      Classification memory node = _nodeTypes[i];
      if (_migratedCount >= node._upperBounds) {
        _typeIndex = i + 1;
      }
    }
    _migrationComplete = true;
  }


  /***********************************|
  |             Modifiers             |
  |__________________________________*/

  modifier whenMigrated() {
    require(_migrationComplete, "LPT:E-003");
    _;
  }

  modifier whenNotMigrated() {
    require(!_migrationComplete, "LPT:E-004");
    _;
  }

  modifier whenNotPaused() {
    require(!_paused, "LPT:E-101");
    _;
  }
}
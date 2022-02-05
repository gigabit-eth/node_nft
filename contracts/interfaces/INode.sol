// SPDX-License-Identifier: MIT

// ILepton.sol -- Part of the Charged Particles Protocol
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

pragma solidity >=0.8.0;

/**
 * @title Project N Node Interface
 * @dev ...
 */
interface INode {

  struct Classification {
    string tokenUri;
    uint256 price;
    uint128 _upperBounds;
    uint32 supply;
    uint32 emission;
    uint32 bonus;
  }

  function mintNode() external payable returns (uint256 newTokenId);
  function batchMintNode(uint256 count) external payable;
  function getNextType() external view returns (uint256);
  function getNextPrice() external view returns (uint256);
  function getEmission(uint256 tokenId) external view returns (uint256);
  function getBonus(uint256 tokenId) external view returns (uint256);


  event MaxMintPerTxSet(uint256 maxAmount);
  event NodeTypeAdded(string tokenUri, uint256 price, uint32 supply, uint32 emission, uint32 bonus, uint256 upperBounds);
  event NodeTypeUpdated(uint256 nodeIndex, string tokenUri, uint256 price, uint32 supply, uint32 emission, uint32 bonus, uint256 upperBounds);
  event NodeMinted(address indexed receiver, uint256 indexed tokenId, uint256 price, uint32 emission);
  event NodeBatchMinted(address indexed receiver, uint256 indexed tokenId, uint256 count, uint256 price, uint32 emission);
  event PausedStateSet(bool isPaused);
}
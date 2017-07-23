// Copyright (c) 2016 The Mlgb developers
// Distributed under the MIT software license, see the accompanying
// file COPYING or http://www.opensource.org/licenses/mit-license.php.

#include "wallet/wallet.h"
#include "mlgb/JoinSplit.hpp"
#include "mlgb/Note.hpp"
#include "mlgb/NoteEncryption.hpp"

CWalletTx GetValidReceive(ZCJoinSplit& params,
                          const libmlgb::SpendingKey& sk, CAmount value,
                          bool randomInputs);
libmlgb::Note GetNote(ZCJoinSplit& params,
                       const libmlgb::SpendingKey& sk,
                       const CTransaction& tx, size_t js, size_t n);
CWalletTx GetValidSpend(ZCJoinSplit& params,
                        const libmlgb::SpendingKey& sk,
                        const libmlgb::Note& note, CAmount value);

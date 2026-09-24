#include "cpp/calculator/calculator.h"

#include "gtest/gtest.h"

namespace calculator {
namespace {

TEST(AddTest, PositiveNumbers) { EXPECT_EQ(Add(2, 3), 5); }

TEST(AddTest, NegativeNumbers) {
  EXPECT_EQ(Add(-1, 1), 0);
  EXPECT_EQ(Add(-4, -6), -10);
}

TEST(AddTest, Zero) { EXPECT_EQ(Add(0, 0), 0); }

}  // namespace
}  // namespace calculator

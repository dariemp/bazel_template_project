// GoogleTest suite for the C calculator library (C code, C++ test harness).
#include "c/calculator/calculator.h"

#include "gtest/gtest.h"

namespace {

TEST(CAddTest, PositiveNumbers) { EXPECT_EQ(add(2, 3), 5); }

TEST(CAddTest, NegativeNumbers) {
  EXPECT_EQ(add(-1, 1), 0);
  EXPECT_EQ(add(-4, -6), -10);
}

TEST(CAddTest, Zero) { EXPECT_EQ(add(0, 0), 0); }

}  // namespace

package calculator

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestAdd(t *testing.T) {
	tests := []struct {
		name       string
		a, b, want int
	}{
		{"positive", 2, 3, 5},
		{"mixed", -1, 1, 0},
		{"zero", 0, 0, 0},
		{"negative", -4, -6, -10},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			assert.Equal(t, tt.want, Add(tt.a, tt.b))
		})
	}
}

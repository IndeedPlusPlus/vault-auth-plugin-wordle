package main

import (
	"testing"
)

func TestWordle(t *testing.T) {
	var w wordle
	ans, err := w.Answer()
	if err != nil {
		t.Fatal(err)
	}
	if len(ans) != 5 {
		t.Errorf("unlikely wordle answer: %s", ans)
	}
	t.Logf("answer is %q", ans)
}

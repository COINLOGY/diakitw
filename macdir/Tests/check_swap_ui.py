from pathlib import Path
import unittest
root=Path(__file__).resolve().parents[1]
class SwapUI(unittest.TestCase):
 def test_swap_after_memory(self):
  text=(root/'Sources/macdir/main.swift').read_text()
  self.assertIn('title: "SWAP"',text)
  self.assertLess(text.index('title: "ПАМЯТЬ"'),text.index('title: "SWAP"'))
  self.assertLess(text.index('title: "SWAP"'),text.index('title: "ДИСК'))
  self.assertNotIn('ForEach(model.snapshot.networks) { net in',text)
 def test_swap_dial_on_both_panels(self):
  for filename in ['main.swift', 'ServerPanel.swift']:
   text=(root/'Sources/macdir'/filename).read_text()
   card=next(line for line in text.splitlines() if 'title: "SWAP"' in line)
   self.assertNotIn('amountOnly: true', card)
   self.assertIn('fraction: GaugeScale.fraction(', card)
   self.assertIn('explanation: MetricPresentation.swapExplanation', card)
   self.assertTrue('utilization(' in card or 'measuredPercent(' in card)
   self.assertTrue('usedTotal(' in card or 'measuredPair(' in card)
 def test_swap_total_from_os(self):
  text=(root/'Sources/MacdirCore/Resources.swift').read_text()
  self.assertIn('s.swapTotal = Int64(swap.xsu_total)',text)
if __name__=='__main__': unittest.main()

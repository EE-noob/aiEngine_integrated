#!/usr/bin/env python3
"""Regression checks for allowed, prohibited and context-limited report terms."""
import re
import unittest

from audit_report import (
    AGENTS_PROHIBITED_EXPRESSIONS, PROHIBITED, REPORT_PROHIBITED_WORDS,
    audit_restricted_terms,
)


class ReportTerminologyTests(unittest.TestCase):
    def test_all_21_prohibited_words_are_detected(self):
        self.assertEqual(len(set(REPORT_PROHIBITED_WORDS)),21)
        for word in REPORT_PROHIBITED_WORDS:
            with self.subTest(word=word):
                self.assertIsNotNone(re.search(PROHIBITED,word))

    def test_quantization_is_allowed(self):
        text='量化方法用于低比特推理，量化误差和量化精度分别统计。'
        self.assertIsNone(re.search(PROHIBITED,text))
        result=audit_restricted_terms(text)
        self.assertEqual(result['quantization_occurrences'],3)
        self.assertEqual(len(result['quantization_examples_present']),3)

    def test_fixed_timing_phrase_is_allowed(self):
        self.assertEqual(audit_restricted_terms('完成时序收敛。')['timing_convergence_occurrences'],1)

    def test_agents_expressions_are_detected(self):
        for expression in AGENTS_PROHIBITED_EXPRESSIONS:
            with self.subTest(expression=expression):
                self.assertIsNotNone(re.search(PROHIBITED,expression))

    def test_other_convergence_uses_are_rejected(self):
        for text in ('结果收敛。','误差收敛。','时序快速收敛。','时序收敛后观察数值收敛。'):
            with self.subTest(text=text),self.assertRaises(AssertionError):
                audit_restricted_terms(text)

    def test_separation_needs_recorded_context_review(self):
        text='模块边界分隔控制模块与计算模块。'
        with self.assertRaises(AssertionError):
            audit_restricted_terms(text)

    def test_concrete_separation_can_be_approved(self):
        for text,reason in (
            ('模块边界分隔控制模块与计算模块。','控制模块与计算模块的结构分隔处'),
            ('流水线寄存器边界分隔相邻计算级。','相邻计算级之间的寄存器分隔处'),
        ):
            with self.subTest(text=text):
                result=audit_restricted_terms(text,boundary_approvals={text:reason})
                self.assertEqual(result['boundary_occurrences'],1)
                self.assertEqual(result['unreviewed_boundary_occurrences'],0)

    def test_approval_does_not_cover_another_occurrence(self):
        excerpt='模块边界分隔控制模块与计算模块。'
        with self.assertRaises(AssertionError):
            audit_restricted_terms(excerpt+'能力边界扩大。',
                boundary_approvals={excerpt:'控制模块与计算模块的结构分隔处'})


if __name__=='__main__':
    unittest.main()

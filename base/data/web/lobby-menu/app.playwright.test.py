"""Compatibility entry point for the old browser smoke-test command.
The shipped lobby is now tested in its actual embedded WebCore renderer.
"""
from pathlib import Path
import runpy

runpy.run_path(str(Path(__file__).resolve().parents[4] / 'Tools/test_webcore_lobby.py'), run_name='__main__')

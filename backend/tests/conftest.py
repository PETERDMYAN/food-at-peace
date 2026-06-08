import os
import sys

# Make the handler in ../src importable as `app` regardless of the cwd pytest
# is invoked from.
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))

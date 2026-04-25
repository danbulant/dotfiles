from setuptools import find_packages, setup

setup(
    name="llama-swap-exporter",
    version="1.0",
    # Modules to import from other scripts:
    packages=find_packages(),
    # Executables
    scripts=["exporter.py"],
)

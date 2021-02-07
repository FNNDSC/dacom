from os import path
from setuptools import setup

with open(path.join(path.abspath(path.dirname(__file__)), 'README.rst')) as f:
    readme = f.read()

setup(
    name             =   'pfcon',
    version          =   '2.4.0',
    description      =   'Process and File Controller',
    long_description =   readme,
    author           =   'Rudolph Pienaar',
    author_email     =   'rudolph.pienaar@gmail.com',
    url              =   'https://github.com/FNNDSC/pfcon',
    packages         =   ['pfcon'],
    scripts          =   ['bin/pfcon'],
    license          =   'MIT',
    zip_safe         =   False,
    python_requires  =   '>=3.6'
)

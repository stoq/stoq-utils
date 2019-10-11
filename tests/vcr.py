import os.path
from vcr import VCR

here = os.path.dirname(os.path.abspath(__file__))

vcr = VCR(
    cassette_library_dir=os.path.join(here, 'resources/cassettes'),
    path_transformer=VCR.ensure_suffix('.yaml'),
    filter_headers=['Private-Token'],
    record_mode='once',
    match_on=['method', 'path', 'query'],
)

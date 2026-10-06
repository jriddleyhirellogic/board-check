VENV    := env
PYTHON  := $(VENV)/bin/python
PIP     := $(VENV)/bin/pip
REQ     := requirements.txt

.PHONY: check-env recv conv conv-pcie conv-aligned conv-unaligned view clean

$(VENV)/bin/activate: $(REQ)
	python3 -m venv $(VENV)
	$(PIP) install --upgrade pip
	$(PIP) install -r $(REQ)
	touch $@

check-env:
	bash check_env.sh

recv:
ifdef VIRTUAL_ENV
	python receiver.py
else
	$(MAKE) $(VENV)/bin/activate
	$(PYTHON) receiver.py
endif

conv:
ifdef VIRTUAL_ENV
	python converter.py
else
	$(MAKE) $(VENV)/bin/activate
	$(PYTHON) converter.py
endif

conv-pcie:
ifdef VIRTUAL_ENV
	python converter_pcie.py
else
	$(MAKE) $(VENV)/bin/activate
	$(PYTHON) converter_pcie.py
endif

conv-aligned:
ifdef VIRTUAL_ENV
	python converter_aligned_raw_to_png.py
else
	$(MAKE) $(VENV)/bin/activate
	$(PYTHON) converter_aligned_raw_to_png.py
endif

conv-unaligned:
ifdef VIRTUAL_ENV
	python converter_unaligned_to_aligned_raw.py
else
	$(MAKE) $(VENV)/bin/activate
	$(PYTHON) converter_unaligned_to_aligned_raw.py
endif

view:
ifdef VIRTUAL_ENV
	python capture_and_view.py
else
	$(MAKE) $(VENV)/bin/activate
	$(PYTHON) capture_and_view.py
endif

clean:
	rm -rf raw_frames captured_4512x4512 __pycache__

# Media Processor

The media processor would be responsible for processing the media files uploaded by the users and applying filters.

## Processing

In order for filters to apply in a uniform manner that is consistent across cameras, the media processor would need a step where it normalizes the image inputs.

1. Find target image to get data from
    - One where the filters are applied and looked ideal
2. Normalize input based on target image
3. Scale image to a standard size (ex. portrait)
4. Apply filters
5. Save output

The normalization is the part that's a bit unknown to me. I'm thinking
- Make the input to a specific color space (ex. sRGB).
- Use the target image's data (maybe histogram, dynamic range) to adjust the input image's data.

```yaml
pods:
  # the analyzer should be its own workload, it should not scale with the processor because it will only be called when creating new filters, not in the regular processing of images.
  - name: analyzer
    containers:
      - name: analyzer
  # the processor handles the pre-processing and the actual processing of the images.
  - name: processor
    containers:
      # this pre-processor would be its own container because I'd likely need to use some special tools, or python, or something for the normalization.
      - name: pre-processor
      # the processor handles the actual filter application
      - name: processor
```

## APIs

### K8s CRDs

Ideally, the filters would be a CR (and/or database entry, depending on the scale) that would be used by the media processor to apply the filters.
The [sample folder](./sample) contains the sample Filter/ColorGrading specs the define the CRDs.

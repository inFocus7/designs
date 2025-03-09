package v1alpha1

import (
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// +kubebuilder:object:root=true
// +kubebuilder:subresource:status
// +kubebuilder:resource:shortName=flt,path=filters,scope=Namespaced

type Filter struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`
	Spec              FilterSpec   `json:"spec,omitempty"`
	Status            FilterStatus `json:"status,omitempty"`
}

type FilterSpec struct {
	// Description is a catchy/fun description of what the filter's purpose is
	// +kubebuilder:example="A filter to make your video look like it was shot on a VHS camera"
	// +kubebuilder:validation:MaxLength=256
	Description string `json:"description"`
	// Example is an optional link to a hosted example online which could be used by a front-end.
	// +kubebuilder:example="https://hostname.com/filters/vhs/example.mp4"
	Example string `json:"example,omitempty"`
	// ColorGrading is the set of color grading effects (LUTs and Curves) to apply to the media in order
	ColorGrading []ColorGradingSpec `json:"colorGrading,omitempty"`
	// FPS is the wanted FPS for the generated media
	// +kubebuilder:example="24"
	// +kubebuilder:validation:Maximum=144
	FPS uint16 `json:"fps,omitempty"`
	// CRF is the wanted CRF for the generated media
	// +kubebuilder:example="18"
	CRF uint16 `json:"crf,omitempty"`
	// PreProcessFilter is the set of effects to apply before handling the color grading (LUT + Curve) and loop
	PreProcessFilter *XFilterSpec `json:"preProcessFilter,omitempty"`
	// PostProcessFilter is the set of effects to apply after handling the color grading (LUT + Curve) and loop
	PostProcessFilter *XFilterSpec `json:"postProcessFilter,omitempty"`
}

// TODO: Can i limit the string options for things like Filter?
// TODO: add things like brightness, saturation, sharpness, vignette, etc? (or should we be opinionated?)
type XFilterSpec struct {
	Brightness int `json:"brightness,omitempty"`
	Contrast   int `json:"contrast,omitempty"`
	Saturation int `json:"saturation,omitempty"`
	// +kubebuilder:example:"21"
	// +kubebuilder:validation:Maximum=100
	Grain uint16 `json:"grain,omitempty"`
	// +kubebuilder:example:"21"
	// +kubebuilder:validation:Maximum=100
	Noise uint16 `json:"noise,omitempty"`
	// TODO: These filters are actually commands, some with subfilters/settings, so i may want to set this up a bit differently so it can apply the chains like blur_type=something=something=1:2:3
	Scale ScaleSpec `json:"scale,omitempty"`
	Blur  BlurSpec  `json:"blur,omitempty"`
}

type ScaleSpec struct {
	Filter string `json:"filter"`
	Div    uint16 `json:"div"`
}

type BlurSpec struct {
	Filter string `json:"filter"`
	Radius int    `json:"radius"`
}

type FilterStatus struct {
	// State is the current state of the filter
	// +kubebuilder:validation:Enum=Pending;Processing;Failed;Accepted
	State       string      `json:"state"`
	LastUpdated metav1.Time `json:"lastUpdated,omitempty"`
}

// +kubebuilder:object:root=true

type FilterList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []Filter `json:"items"`
}

func init() {
	SchemeBuilder.Register(&Filter{}, &FilterList{})
}

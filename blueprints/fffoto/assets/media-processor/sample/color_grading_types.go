package v1alpha1

import (
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

type RefSpec struct {
	InternalRef *InternalRefSpec `json:"internalRef,omitempty"`
	ExternalRef *ExternalRefSpec `json:"externalRef,omitempty"`
}

type InternalRefSpec struct {
	// Path is the path to the file
	// +kubebuilder:example="/path/to/file"
	Path string `json:"path"`
}

// TODO: May need/want to expand CRD for security during reconciliation when fetching from online source?
type ExternalRefSpec struct {
	// URL is the URL to the file
	// +kubebuilder:example="https://hostname.com/path/to/file"
	URL string `json:"url"`
}

// +kubebuilder:object:root=true
// +kubebuilder:subresource:status
// +kubebuilder:resource:shortName=cg,path=colorGradings,scope=Namespaced

type ColorGrading struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`
	Spec              ColorGradingSpec `json:"spec,omitempty"`
	Status            ColorGradingSpec `json:"status,omitempty"`
}

type ColorGradingSpec struct {
	// Description is a technical description of what the curve does
	// +kubebuilder:example="A curve to adjust the gamma of the video"
	// +kubebuilder:validation:MaxLength=256
	Description string `json:"description"`
	// Type is the type of grading (LUT, Curve, etc)
	// +kubebuilder:validation:Enum=LUT;Curve
	Type string  `json:"type"`
	Ref  RefSpec `json:"ref"`
}

type ColorGradingStatus struct {
	// State is the current state of the curve
	// +kubebuilder:validation:Enum=Pending;Processing;Failed;Accepted
	State       string      `json:"state"`
	LastUpdated metav1.Time `json:"lastUpdated,omitempty"`
}

// +kubebuilder:object:root=true

type ColorGradingList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []ColorGrading `json:"items"`
}

func init() {
	SchemeBuilder.Register(&ColorGrading{}, &ColorGrading{})
}

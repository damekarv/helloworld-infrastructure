package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"sort"
	"strings"
	"time"

	"github.com/blang/semver/v4"
	"github.com/google/go-containerregistry/pkg/crane"
)

type ReleaseManifest struct {
	ReleaseVersion string    `json:"release_version"`
	Services       []Service `json:"services"`
}

type Service struct {
	Name    string `json:"name"`
	Version string `json:"version"`
	Image   string `json:"image"`
}

func main() {
	fmt.Println("Starting Registry Watcher...")

	// 1. Load Manifest
	manifest, err := loadManifest("release_manifest.json")
	if err != nil {
		panic(fmt.Errorf("failed to load manifest: %w", err))
	}

	updated := false

	// 2. Check Services
	for i, svc := range manifest.Services {
		fmt.Printf("Checking %s (%s)...\n", svc.Name, svc.Image)

		latestTag, err := getLatestTag(svc.Image)
		if err != nil {
			fmt.Printf("  Warning: failed to get tags for %s: %v\n", svc.Name, err)
			continue
		}

		if latestTag != svc.Version && latestTag != "" {
			fmt.Printf("  Found new version: %s (was %s)\n", latestTag, svc.Version)

			// Update Manifest Object
			manifest.Services[i].Version = latestTag

			// Update YAML (using yq to preserve comments/structure)
			// yq -i "select(.metadata.name == \"$NAME\").spec.values.image.tag = \"$LATEST_TAG\"" clusters/dev/release.yaml
			cmd := exec.Command("yq", "-i",
				fmt.Sprintf("select(.metadata.name == \"%s\").spec.values.image.tag = \"%s\"", svc.Name, latestTag),
				"clusters/dev/release.yaml")
			if out, err := cmd.CombinedOutput(); err != nil {
				panic(fmt.Errorf("yq failed: %s: %w", out, err))
			}

			updated = true
		} else {
			fmt.Println("  Up to date.")
		}
	}

	// 3. Generate New Release Version if Updated
	if updated {
		newRelVer := generateNextVersion(manifest.ReleaseVersion)
		fmt.Printf("Generating new release version: %s\n", newRelVer)
		manifest.ReleaseVersion = newRelVer

		// Save Manifest
		if err := saveManifest("release_manifest.json", manifest); err != nil {
			panic(fmt.Errorf("failed to save manifest: %w", err))
		}

		// Output for GitHub Actions
		appendToGithubOutput("update", "true")
		appendToGithubOutput("release_tag", newRelVer)
	} else {
		appendToGithubOutput("update", "false")
	}
}

func loadManifest(path string) (*ReleaseManifest, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var m ReleaseManifest
	err = json.Unmarshal(data, &m)
	return &m, err
}

func saveManifest(path string, m *ReleaseManifest) error {
	data, err := json.MarshalIndent(m, "", "    ")
	if err != nil {
		return err
	}
	return os.WriteFile(path, data, 0644)
}

func getLatestTag(image string) (string, error) {
	tags, err := crane.ListTags(image)
	if err != nil {
		return "", err
	}

	// Filter for v* and sort
	var versions []string
	for _, t := range tags {
		if strings.HasPrefix(t, "v") {
			versions = append(versions, t)
		}
	}

	if len(versions) == 0 {
		return "", nil
	}

	// Sort semantically
	sort.Slice(versions, func(i, j int) bool {
		v1, err1 := semver.ParseTolerant(versions[i])
		v2, err2 := semver.ParseTolerant(versions[j])
		if err1 != nil || err2 != nil {
			return versions[i] < versions[j] // Fallback to string sort
		}
		return v1.LT(v2)
	})

	return versions[len(versions)-1], nil
}

func generateNextVersion(current string) string {
	// Format: vYearWeek.Minor.Patch (e.g., v202602.1.0)
	now := time.Now().UTC()
	year, week := now.ISOWeek()
	prefix := fmt.Sprintf("v%d%02d", year, week)

	if strings.HasPrefix(current, prefix) {
		// Same week: increment minor
		// current: v202602.1.0
		// trim prefix+dot: 1.0
		remainder := strings.TrimPrefix(current, prefix+".")
		parts := strings.Split(remainder, ".")
		if len(parts) > 0 {
			var minor int
			fmt.Sscanf(parts[0], "%d", &minor)
			return fmt.Sprintf("%s.%d.0", prefix, minor+1)
		}
	}

	// New week or parse error: reset
	return fmt.Sprintf("%s.0.0", prefix)
}

func appendToGithubOutput(key, value string) {
	f, err := os.OpenFile(os.Getenv("GITHUB_OUTPUT"), os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		// Fallback for local testing
		fmt.Printf("::set-output name=%s::%s\n", key, value)
		return
	}
	defer f.Close()
	if _, err := f.WriteString(fmt.Sprintf("%s=%s\n", key, value)); err != nil {
		fmt.Printf("Failed to write to GITHUB_OUTPUT: %v\n", err)
	}
}
